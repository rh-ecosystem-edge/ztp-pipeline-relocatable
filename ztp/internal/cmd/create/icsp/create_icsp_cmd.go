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

package icsp

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"gopkg.in/yaml.v3"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Cobra creates and returns the `create icsp` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:     "icsp",
		Aliases: []string{"icsps"},
		Short:   "Creates the image content source policies",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	return result
}

// Command contains the data and logic needed to run the `create icsp` command.
type Command struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// Task contains the information necessary to complete each of the tasks that this command runs, in
// particular it contains the reference to the cluster it works with, so that it isn't necessary to
// pass this reference around all the time.
type Task struct {
	parent  *Command
	logger  logr.Logger
	console *internal.Console
	client  *internal.Client
	cluster *models.Cluster
}

// NewCommand creates a new runner that knows how to execute the `create icsp` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `create icsp` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) error {
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
			"Failed to create client: %v",
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
		task := &Task{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			console: c.console,
			cluster: cluster,
		}
		err = task.Run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create image content source policies for "+
					"cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	return nil
}

func (t *Task) Run(ctx context.Context) error {
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
		return fmt.Errorf(
			"SSH key for cluster '%s' isn't available",
			t.cluster.Name,
		)
	}

	// Check that the registry URI and CA are available:
	if t.cluster.Registry.URL == "" {
		return fmt.Errorf(
			"registry URL for cluster '%s' isn't available",
			t.cluster.Name,
		)
	}
	if t.cluster.Registry.CA == nil {
		return fmt.Errorf(
			"registry CA for cluster '%s' ins't available",
			t.cluster.Name,
		)
	}

	// Find the first control plane node that has an external IP:
	var sshIP *models.IP
	for _, node := range t.cluster.ControlPlaneNodes() {
		if node.ExternalIP != nil {
			sshIP = node.ExternalIP
			break
		}
	}
	if sshIP == nil {
		return fmt.Errorf(
			"failed to find SSH host for cluster '%s' because there is no control "+
				"plane node that has an external IP address",
			t.cluster.Name,
		)
	}

	// Create the client using a dialer that creates connections tunnelled via the SSH
	// connection to the cluster:
	t.client, err = internal.NewClient().
		SetLogger(t.logger).
		SetFlags(t.parent.flags).
		SetKubeconfig(t.cluster.Kubeconfig).
		SetSSHServer(sshIP.Address.String()).
		SetSSHUser("core").
		SetSSHKey(t.cluster.SSH.PrivateKey).
		Build()
	if err != nil {
		return err
	}

	// Get the list of catalogs of the hub:
	catalogs := &unstructured.UnstructuredList{}
	catalogs.SetGroupVersionKind(internal.CatalogSourceListGVK)
	err = t.parent.client.List(ctx, catalogs, clnt.InNamespace("openshift-marketplace"))
	if err != nil {
		return err
	}

	// Configure the cluster so that it trusts the registry:
	err = t.trustRegistry(ctx, t.cluster.Registry.URL, t.cluster.Registry.CA)
	if err != nil {
		return err
	}

	// Create the image content source policies:
	for _, catalog := range catalogs.Items {
		err = t.createCatalogICSP(ctx, &catalog, t.cluster.Registry.URL)
		if err != nil {
			return err
		}
	}

	return nil
}

func (t *Task) trustRegistry(ctx context.Context, registryURI string, registryCA []byte) error {
	// Create the configmap containing the additional trusted CA certificates:
	trustedCAConfig := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: "openshift-config",
			Name:      "ztpfwregistry",
		},
		Data: map[string]string{
			registryURI: string(registryCA),
		},
	}
	err := t.client.Create(ctx, trustedCAConfig)
	switch {
	case err == nil:
		t.console.Info(
			"Created additional trusted CA '%s' for registry '%s' in cluster '%s'",
			trustedCAConfig, registryURI, t.cluster.Name,
		)
	case apierrors.IsAlreadyExists(err):
		t.console.Warn(
			"Additional trusted CA '%s' for registry '%s' already exists in "+
				"cluster '%s'",
			trustedCAConfig, registryURI, t.cluster.Name,
		)
	default:
		return err
	}

	// Update the cluster configuration to trust the CA certificates:
	imageConfig := &unstructured.Unstructured{}
	imageConfig.SetGroupVersionKind(internal.ImageConfigGVK)
	imageKey := clnt.ObjectKey{
		Namespace: "openshift-config",
		Name:      "cluster",
	}
	err = t.client.Get(ctx, imageKey, imageConfig)
	if err != nil {
		return err
	}
	imageUpdate := imageConfig.DeepCopy()
	err = unstructured.SetNestedField(
		imageUpdate.Object,
		trustedCAConfig.Name,
		"spec", "additionalTrustedCA", "name",
	)
	if err != nil {
		return err
	}
	err = t.client.Patch(ctx, imageUpdate, clnt.MergeFrom(imageConfig))
	if err != nil {
		return err
	}
	t.console.Info(
		"Updated image pull configuration of cluster '%s' to trust registry '%s'",
		t.cluster.Name, registryURI,
	)

	return nil
}

func (t *Task) createCatalogICSP(ctx context.Context, catalog *unstructured.Unstructured,
	registry string) error {
	t.console.Info(
		"Generating ICSP for catalog '%s' of cluster '%s'",
		catalog, t.cluster.Name,
	)
	icsp, err := t.generateCatalogICSP(ctx, catalog, registry)
	if err != nil {
		return err
	}
	err = t.client.Create(ctx, icsp)
	if apierrors.IsAlreadyExists(err) {
		t.console.Warn(
			"ICSP '%s' for catalog '%s' of cluster '%s' already exists",
			icsp, catalog, t.cluster.Name,
		)
		err = nil
	}
	if err != nil {
		return err
	}
	t.console.Info(
		"Created ICSP '%s' for catalog '%s' of cluster '%s'",
		icsp, catalog, t.cluster.Name,
	)
	return nil
}

func (t *Task) generateCatalogICSP(ctx context.Context, catalog *unstructured.Unstructured,
	registry string) (result *unstructured.Unstructured, err error) {
	t.logger.V(1).Info(
		"Generating ICSP for catalog source",
		"catalog", fmt.Sprintf("%s/%s", catalog.GetNamespace(), catalog.GetName()),
		"registry", registry,
	)
	var index string
	err = t.parent.jq.Query(`.spec.image`, catalog.Object, &index)
	if err != nil {
		return
	}
	result, err = t.generateIndexICSP(ctx, index, fmt.Sprintf("%s/olm", registry))
	return
}

func (t *Task) generateIndexICSP(ctx context.Context,
	index, target string) (result *unstructured.Unstructured, err error) {
	// We need to use the `ocm adm catalog mirror` command to generate the image content source
	// policy. To do so we create a directory, write the pull secret to a file, and then run the
	// command to generate the result in the same directory.
	t.logger.V(1).Info(
		"Generating ICSP for index image",
		"index", index,
		"target", target,
	)
	tmpDir, err := os.MkdirTemp("", "*.icsp")
	if err != nil {
		return
	}
	defer os.RemoveAll(tmpDir)
	tmpAuth := filepath.Join(tmpDir, "auth.json")
	err = os.WriteFile(tmpAuth, t.cluster.PullSecret, 0600)
	if err != nil {
		return
	}
	ocPath, err := exec.LookPath("oc")
	if err != nil {
		return
	}
	ocIn := &bytes.Buffer{}
	ocOut := &bytes.Buffer{}
	ocErr := &bytes.Buffer{}
	ocCmd := &exec.Cmd{
		Path: ocPath,
		Args: []string{
			"oc",
			"adm", "catalog", "mirror",
			"--insecure",
			"--registry-config", tmpAuth,
			"--manifests-only",
			"--to-manifests", tmpDir,
			index, target,
		},
		Dir:    tmpDir,
		Env:    append(os.Environ(), "GODEBUG=x509ignoreCN=0"),
		Stdin:  ocIn,
		Stdout: ocOut,
		Stderr: ocErr,
	}
	err = ocCmd.Run()
	t.logger.V(2).Info(
		"Executed catalog mirror command",
		"env", ocCmd.Env,
		"cwd", ocCmd.Dir,
		"args", ocCmd.Args,
		"stdout", ocOut.String(),
		"stderr", ocErr.String(),
		"code", ocCmd.ProcessState.ExitCode(),
	)
	if err != nil {
		return
	}

	// Now we parse the generated YAML to generate the object:
	tmpFile := filepath.Join(tmpDir, "imageContentSourcePolicy.yaml")
	tmpData, err := os.ReadFile(tmpFile)
	if err != nil {
		return
	}
	tmpObject := &unstructured.Unstructured{}
	err = yaml.Unmarshal(tmpData, &tmpObject.Object)
	if err != nil {
		return
	}

	// Return the resulting object:
	result = tmpObject
	return
}
