/*
Copyright 2023 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package registry

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/go-logr/logr"
	"github.com/imdario/mergo"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"golang.org/x/crypto/ssh"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/quay"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Create creates and returns the `create registry` command.
func Create() *cobra.Command {
	c := NewCreateCommand()
	result := &cobra.Command{
		Use:     "registry",
		Aliases: []string{"registries"},
		Short:   "Deploys the registry",
		Args:    cobra.NoArgs,
		RunE:    c.run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// CreateCommand contains the data and logic needed to run the `create registry` command.
type CreateCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// CreateTask contains the information necessary to complete each of the tasks that this command
// runs, in particular it contains the reference to the cluster it works with, so that it isn't
// necessary to pass this reference around all the time.
type CreateTask struct {
	parent  *CreateCommand
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	cluster *models.Cluster
	client  *internal.Client
}

// NewCreateCommand creates a new runner that knows how to execute the `create registry` command.
func NewCreateCommand() *CreateCommand {
	return &CreateCommand{}
}

// run runs the `create registry` command.
func (c *CreateCommand) run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.console = internal.ConsoleFromContext(ctx)

	// Save the flags:
	c.flags = cmd.Flags()

	// Create the jq tool:
	c.jq, err = jq.NewTool().
		SetLogger(c.logger).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create jq tool: %v",
			err,
		)
		return exit.Error(1)
	}

	// Load the configuration:
	c.config, err = config.NewLoader().
		SetLogger(c.logger).
		SetFlags(c.flags).
		Load()
	if err != nil {
		c.console.Error(
			"Failed to load configuration: %v",
			err,
		)
		return exit.Error(1)
	}

	// Create the client for the API:
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetFlags(c.flags).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create API client: %v",
			err,
		)
		return exit.Error(1)
	}

	// Enrich the configuration:
	enricher, err := internal.NewEnricher().
		SetLogger(c.logger).
		SetClient(c.client).
		SetFlags(c.flags).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create enricher: %v",
			err,
		)
		return exit.Error(1)
	}
	err = enricher.Enrich(ctx, c.config)
	if err != nil {
		c.console.Error(
			"Failed to enrich configuration: %v",
			err,
		)
		return exit.Error(1)
	}

	// Create a task for each cluster, and run them:
	for _, cluster := range c.config.Clusters {
		task := &CreateTask{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			flags:   c.flags,
			jq:      c.jq,
			console: c.console,
			cluster: cluster,
		}
		err = task.run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create registry for cluster '%s': %v",
				cluster.Name, err,
			)
			return exit.Error(1)
		}
	}

	return nil
}

func (t *CreateTask) run(ctx context.Context) error {
	var err error

	// Check that the Kubeconfig is available:
	if t.cluster.Kubeconfig == nil {
		return fmt.Errorf(
			"kubeconfig for cluster '%s' isn't available",
			t.cluster.Name,
		)
	}

	// Check that the SSH key is available:
	if t.cluster.SSH.PrivateKey == nil {
		return fmt.Errorf("SSH key isn't available")
	}

	// Check that the IP addreses of all the nodes are available. This is necessary because we
	// are going to connect to those nodes via SSH to install the registry CA and restart the
	// services.
	var missing []string
	for _, node := range t.cluster.Nodes {
		if node.ExternalIP == nil {
			missing = append(missing, node.Name)
		}
	}
	if len(missing) > 0 {
		if len(missing) > 1 {
			return fmt.Errorf(
				"IP addresses of nodes %s aren't available",
				logging.All(missing),
			)
		}
		return fmt.Errorf(
			"IP address of node '%s' isn't available",
			missing[0],
		)
	}

	// Create the client to connect to the cluster:
	t.client, err = internal.NewClient().
		SetLogger(t.logger).
		SetFlags(t.flags).
		SetKubeconfig(t.cluster.Kubeconfig).
		Build()
	if err != nil {
		return err
	}

	// Deploy the registry:
	err = t.deployRegistry(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (t *CreateTask) deployRegistry(ctx context.Context) error {
	// Create the applier:
	listener, err := internal.NewApplierListener().
		SetLogger(t.logger).
		SetConsole(t.console).
		Build()
	if err != nil {
		return err
	}
	applier, err := internal.NewApplier().
		SetLogger(t.logger).
		SetListener(listener.Func).
		SetClient(t.client).
		SetFS(templatesFS).
		SetRoot("templates/quay").
		SetDir("objects").
		Build()
	if err != nil {
		return err
	}

	// Create the objects:
	objects, err := applier.Render(ctx, nil)
	if err != nil {
		return err
	}
	err = applier.ApplyObjects(ctx, objects)
	if err != nil {
		return err
	}

	// Wait for the registry to be available:
	var registry *unstructured.Unstructured
	for _, object := range objects {
		if object.GroupVersionKind() == internal.QuayRegistryGVK {
			registry = object
			break
		}
	}
	if registry == nil {
		return fmt.Errorf(
			"failed to find regisry for cluster '%s'",
			t.cluster.Name,
		)
	}
	t.console.Info(
		"Waiting for registry '%s' for cluster '%s' to be available",
		registry, t.cluster.Name,
	)
	err = t.waitRegistry(ctx, registry)
	if err != nil {
		return err
	}

	// Check if the secret containing the registry user and password is available:
	var registryUser, registryPass string
	secretObject := &corev1.Secret{}
	secretKey := clnt.ObjectKey{
		Namespace: registry.GetNamespace(),
		Name:      "quay-token",
	}
	err = t.client.Get(ctx, secretKey, secretObject)
	switch {
	case err == nil:
		t.console.Warn(
			"Registry token secret '%s' for cluster '%s' already exists",
			secretKey, t.cluster.Name,
		)
		registryUser = string(secretObject.Data["user"])
		registryPass = string(secretObject.Data["token"])
	case apierrors.IsNotFound(err):
		t.console.Info(
			"Registry secret '%s' for cluster '%s' doesn't exist, will initialize "+
				"the registry",
			secretKey, t.cluster.Name,
		)
		registryUser, registryPass, err = t.initializeRegistry(ctx, registry)
		if err != nil {
			return err
		}
		secretObject.Namespace = secretKey.Namespace
		secretObject.Name = secretKey.Name
		secretObject.Data = map[string][]byte{
			"user":  []byte(registryUser),
			"token": []byte(registryPass),
		}
		err = t.client.Create(ctx, secretObject)
		if err != nil {
			return err
		}
		t.console.Info(
			"Created registry secret '%s' for cluster '%s'",
			secretKey, t.cluster.Name,
		)
	default:
		return err
	}

	// Find the address of the registry:
	routeObject := &unstructured.Unstructured{}
	routeObject.SetGroupVersionKind(internal.RouteGVK)
	routeKey := clnt.ObjectKey{
		Namespace: registry.GetNamespace(),
		Name:      fmt.Sprintf("%s-quay", registry.GetName()),
	}
	err = t.client.Get(ctx, routeKey, routeObject)
	if err != nil {
		return err
	}
	var registryHost string
	err = t.jq.Query(
		`.status.ingress[0]?.host`,
		routeObject, &registryHost,
	)
	if err != nil {
		return err
	}
	if registryHost == "" {
		return fmt.Errorf(
			"failed to update pull secret for cluster '%s' because route '%s' "+
				"doesn't have a host",
			t.cluster.Name, routeKey,
		)
	}
	t.logger.V(1).Info(
		"Found registry host",
		"host", registryHost,
	)

	// Create a pull secret using the administrator credentials:
	pullSecretObject := &corev1.Secret{}
	pullSecretKey := clnt.ObjectKey{
		Namespace: "openshift-config",
		Name:      "pull-secret",
	}
	err = t.client.Get(ctx, pullSecretKey, pullSecretObject)
	if err != nil {
		return err
	}
	pullSecretBytes, ok := pullSecretObject.Data[".dockerconfigjson"]
	if !ok {
		return fmt.Errorf(
			"failed to update pull secret for cluster '%s' because secret '%s' "+
				"doesn't contain the '.dockerconfigjson' key",
			t.cluster.Name, pullSecretKey,
		)
	}
	var pullSecretAuths map[string]any
	err = json.Unmarshal(pullSecretBytes, &pullSecretAuths)
	if err != nil {
		return err
	}
	var existingAuth string
	err = t.jq.Query(
		fmt.Sprintf(`.auths["%s"].auth`, registryHost),
		pullSecretAuths, &existingAuth,
	)
	if err != nil {
		return err
	}
	registryAuth := base64.StdEncoding.EncodeToString([]byte(
		fmt.Sprintf("%s:%s", registryUser, registryPass),
	))
	if existingAuth == registryAuth {
		t.console.Warn(
			"Pull secret for cluster '%s' already contains auth for registry '%s'",
			t.cluster.Name, registryHost,
		)
	} else {
		err = mergo.MapWithOverwrite(&pullSecretAuths, map[string]any{
			"auths": map[string]any{
				registryHost: map[string]any{
					"auth": registryAuth,
				},
			},
		})
		if err != nil {
			return err
		}
		pullSecretBytes, err = json.Marshal(pullSecretAuths)
		if err != nil {
			return err
		}
		pullSecretUpdate := pullSecretObject.DeepCopy()
		pullSecretUpdate.Data[".dockerconfigjson"] = pullSecretBytes
		err = t.client.Patch(ctx, pullSecretUpdate, clnt.MergeFrom(pullSecretObject))
		if err != nil {
			return err
		}
		t.console.Info(
			"Added auth for registry '%s' to pull secret for cluster '%s'",
			registryHost, t.cluster.Name,
		)
	}

	// Configure the cluster so that it trusts the registry:
	err = t.trustRegistry(ctx, registryHost)
	if err != nil {
		return err
	}

	return nil
}

func (t *CreateTask) waitRegistry(ctx context.Context, registry *unstructured.Unstructured) error {
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.QuayRegistryListGVK)
	namespace := registry.GetNamespace()
	name := registry.GetName()
	watch, err := t.client.Watch(
		ctx, list,
		clnt.InNamespace(namespace),
		clnt.MatchingFields{
			"metadata.name": name,
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	for event := range watch.ResultChan() {
		object, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		var available string
		err = t.jq.Query(
			`.status.conditions[]? | select(.type == "Available") | .status`,
			object.Object, &available,
		)
		if err != nil {
			return err
		}
		if available == "True" {
			t.console.Info(
				"Registry '%s' of cluster '%s' is now available",
				registry, t.cluster.Name,
			)
			return nil
		}
	}
	return fmt.Errorf(
		"timed out while waiting for registry '%s/%s' of cluster '%s' to be ready",
		namespace, name, t.cluster.Name,
	)
}

func (t *CreateTask) initializeRegistry(ctx context.Context,
	registry *unstructured.Unstructured) (user, pass string, err error) {
	// Get the API host name from the routeObject:
	routeObject := &unstructured.Unstructured{}
	routeObject.SetGroupVersionKind(internal.RouteGVK)
	routeKey := clnt.ObjectKey{
		Namespace: registry.GetNamespace(),
		Name:      fmt.Sprintf("%s-quay", registry.GetName()),
	}
	err = t.client.Get(ctx, routeKey, routeObject)
	if err != nil {
		return
	}
	var quayHost string
	err = t.jq.Query(
		`.status.ingress[0]?.host`,
		routeObject, &quayHost,
	)
	if err != nil {
		return
	}
	if quayHost == "" {
		err = fmt.Errorf(
			"failed to initialize registry for cluster '%s' because route '%s' "+
				"doesn't have a host",
			t.cluster.Name, routeKey,
		)
		return
	}
	quayURL := fmt.Sprintf("https://%s", quayHost)
	t.logger.V(1).Info(
		"Found registry host",
		"host", quayHost,
		"url", quayURL,
	)

	// Create the client for the registry API:
	quayClient, err := quay.NewClient().
		SetLogger(t.logger).
		SetURL(quayURL).
		SetInsecure(true).
		SetFlags(t.flags).
		Build()
	if err != nil {
		return
	}

	// Enable the administrator user:
	_, err = quayClient.UserInitialize(ctx, &quay.UserInitializeRequest{
		Username:    quayAdminUser,
		Password:    quayAdminPass,
		Email:       quayAdminMail,
		AccessToken: true,
	})
	if err != nil {
		return
	}
	quayAdminToken := quayClient.Token()
	t.logger.V(1).Info(
		"Initialized registry administrator",
		"user", quayAdminUser,
		"mail", quayAdminMail,
		"!password", quayAdminPass,
		"!token", quayAdminToken,
	)
	t.console.Info(
		"Initialized registry administrator '%s' for cluster '%s'",
		quayAdminUser, t.cluster.Name,
	)

	// Create the organizations that are required for mirroring to succeed:
	err = quayClient.OrganizationCreate(ctx, &quay.OrganizationCreateRequest{
		Name:  quayOrgName,
		Email: quayOrgMail,
	})
	if err != nil {
		return
	}
	t.logger.V(1).Info(
		"Created registry organization",
		"name", quayOrgName,
		"mail", quayOrgMail,
	)
	t.console.Info(
		"Created registry organizations '%s' for cluster '%s'",
		quayOrgName, t.cluster.Name,
	)

	// Return the user name and the token:
	user = quayAdminUser
	pass = quayAdminPass
	return
}

func (t *CreateTask) trustRegistry(ctx context.Context, address string) error {
	// Do nothing if the registry is already trusted:
	tool, err := internal.NewRegistryTool().
		SetLogger(t.logger).
		SetClient(t.client).
		Build()
	if err != nil {
		return err
	}
	ca, err := tool.FetchCA(address)
	if err != nil {
		return err
	}
	trusted, err := tool.IsTrusted(ctx, address, ca)
	if err != nil {
		return err
	}
	if trusted {
		t.console.Warn(
			"Registry '%s' is already trusted in cluster '%s'",
			address, t.cluster.Name,
		)
		return nil
	}

	// Install the registry CA in the nodes of the cluster:
	for _, node := range t.cluster.Nodes {
		t.console.Info(
			"Installing registry CA on node '%s' of cluster '%s'",
			node.Name, t.cluster.Name,
		)
		err = t.installCA(ctx, node, ca)
		if err != nil {
			return err
		}
	}

	// Add the trusted registry:
	err = tool.AddTrusted(ctx, address, ca)
	if err != nil {
		return err
	}
	t.console.Info(
		"Added trusted registry '%s' to cluster '%s'",
		address, t.cluster.Name,
	)

	return nil
}

func (t *CreateTask) installCA(ctx context.Context, node *models.Node, ca []byte) error {
	// Create a logger specific for this node:
	logger := t.logger.WithValues("node", node.Name)

	// Parse the key:
	key, err := ssh.ParsePrivateKey(t.cluster.SSH.PrivateKey)
	if err != nil {
		return err
	}

	// Create the SSH session:
	server := fmt.Sprintf("%s:22", node.ExternalIP.Address)
	client, err := ssh.Dial("tcp", server, &ssh.ClientConfig{
		User: "core",
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(key),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	})
	if err != nil {
		return err
	}
	session, err := client.NewSession()
	if err != nil {
		return err
	}
	logger.Info(
		"Created SSH session",
		"server", server,
	)
	defer session.Close()

	// Generate the script:
	engine, err := templating.NewEngine().
		SetLogger(t.logger).
		SetFS(templatesFS).
		SetDir("templates/scripts").
		Build()
	if err != nil {
		return err
	}
	buffer := &bytes.Buffer{}
	err = engine.Execute(buffer, "install_registry_ca.sh", map[string]any{
		"CA": string(ca),
	})
	if err != nil {
		return err
	}
	script := buffer.String()
	logger.V(1).Info(
		"Generated script to install registry CA",
		"ca", string(ca),
		"script", script,
	)

	// Execute the script:
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	session.Stdout = stdout
	session.Stderr = stderr
	err = session.Run(script)
	logger.V(1).Info(
		"Executed script to install registry CA",
		"stdout", stdout.String(),
		"stderr", stderr.String(),
	)
	if err != nil {
		return err
	}

	return nil
}

// Details of the quay administrator user:
const (
	quayAdminUser = "dummy"
	quayAdminMail = "admin@example.com"
	quayAdminPass = "dummy123"
	quayOrgName   = "ztpfw"
	quayOrgMail   = "ztpfw@redht.com"
)
