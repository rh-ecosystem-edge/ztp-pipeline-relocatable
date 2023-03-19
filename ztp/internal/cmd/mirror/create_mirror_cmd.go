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

package mirror

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/Masterminds/semver/v3"
	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/environment"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Create creates and returns the `create mirror` command.
func Create() *cobra.Command {
	c := NewCreateCommand()
	result := &cobra.Command{
		Use:   "mirror",
		Short: "Mirrors the OCP and OLM images",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// CreateCommand contains the data and logic needed to run the `create mirror` command.
type CreateCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	tool    *internal.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// CreateTask contains the information necessary to complete each of the tasks that this command
// runs, in particular it contains the reference to the cluster it works with, so that it isn't
// necessary to pass this reference around all the time.
type CreateTask struct {
	parent                  *CreateCommand
	logger                  logr.Logger
	flags                   *pflag.FlagSet
	jq                      *jq.Tool
	tool                    *internal.Tool
	console                 *internal.Console
	ocpVersion              *semver.Version
	odfVersion              *semver.Version
	redhatOperatorsIndex    string
	certifiedOperatorsIndex string
	cluster                 *models.Cluster
	client                  *internal.Client
}

// NewCreateCommand creates a new runner that knows how to execute the `create mirror` command.
func NewCreateCommand() *CreateCommand {
	return &CreateCommand{}
}

// run runs the `create mirror` command.
func (c *CreateCommand) run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.tool = internal.ToolFromContext(ctx)
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

	// Check that the OCP and ODF versions is set, and convert them into semver objects so that
	// they are easier to manipulate in the templates:
	ocpVersionText, ok := c.config.Properties[models.OCPVersionProperty]
	if !ok {
		return fmt.Errorf(
			"OCP version property '%s' isn't set",
			models.OCPVersionProperty,
		)
	}
	ocpVersion, err := semver.NewVersion(ocpVersionText)
	if err != nil {
		return fmt.Errorf(
			"failed to parse OCP version '%s': %v",
			ocpVersionText, err,
		)
	}
	odfVersionText, ok := c.config.Properties[models.ODFVersionProperty]
	if !ok {
		return fmt.Errorf(
			"ODF version property '%s' isn't set",
			models.ODFVersionProperty,
		)
	}
	odfVersion, err := semver.NewVersion(odfVersionText)
	if err != nil {
		return fmt.Errorf(
			"failed to parse ODF version '%s': %v",
			odfVersionText, err,
		)
	}

	// Find the catalog images:
	redhatOperatorsIndex, err := c.catalogImage(ctx, "redhat-operators")
	if err != nil {
		return err
	}
	certifiedOperatorsIndex, err := c.catalogImage(ctx, "certified-operators")
	if err != nil {
		return err
	}

	// Create a task for each cluster, and run them:
	for _, cluster := range c.config.Clusters {
		task := &CreateTask{
			parent:                  c,
			logger:                  c.logger.WithValues("cluster", cluster.Name),
			flags:                   c.flags,
			jq:                      c.jq,
			tool:                    c.tool,
			ocpVersion:              ocpVersion,
			odfVersion:              odfVersion,
			redhatOperatorsIndex:    redhatOperatorsIndex,
			certifiedOperatorsIndex: certifiedOperatorsIndex,
			console:                 c.console,
			cluster:                 cluster,
		}
		err = task.run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create mirror for cluster '%s': %v",
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

	// Create the client to connect to the cluster:
	t.client, err = internal.NewClient().
		SetLogger(t.logger).
		SetFlags(t.flags).
		SetKubeconfig(t.cluster.Kubeconfig).
		Build()
	if err != nil {
		return err
	}

	// Mirror the images:
	err = t.mirrorImages(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (c *CreateCommand) catalogImage(ctx context.Context, name string) (result string, err error) {
	object := &unstructured.Unstructured{}
	object.SetGroupVersionKind(internal.CatalogSourceGVK)
	key := clnt.ObjectKey{
		Namespace: "openshift-marketplace",
		Name:      name,
	}
	err = c.client.Get(ctx, key, object)
	if apierrors.IsNotFound(err) {
		c.logger.V(1).Info(
			"Failed to find catalog image, source doesn't exist",
			"catalog", name,
			"source", key,
		)
		err = nil
		return
	}
	if err != nil {
		return
	}
	var image string
	err = c.jq.Query(`.spec.image`, object, &image)
	if err != nil {
		return
	}
	if image == "" {
		c.logger.V(1).Info(
			"Failed to find catalog image, source spec doesn't have image",
			"catalog", name,
			"source", key,
		)
	} else {
		c.logger.V(1).Info(
			"Found catalog image",
			"catalog", name,
			"source", key,
			"image", result,
		)
	}
	colon := strings.LastIndex(image, ":")
	if colon != -1 {
		result = image[0:colon]
	} else {
		result = image
	}
	return
}

func (t *CreateTask) mirrorImages(ctx context.Context) error {
	// Create a temporary directory:
	tmpDir, err := os.MkdirTemp("", "*.mirror")
	if err != nil {
		return err
	}
	defer func() {
		err := os.RemoveAll(tmpDir)
		if err != nil {
			t.logger.Error(
				err,
				"Failed to remove temporary directory '%s': %v",
				tmpDir, err,
			)
		}
	}()

	// Find the destination registry:
	routeObject := &unstructured.Unstructured{}
	routeObject.SetGroupVersionKind(internal.RouteGVK)
	routeKey := clnt.ObjectKey{
		Namespace: "ztpfw-registry",
		Name:      "ztpfw-registry-quay",
	}
	err = t.client.Get(ctx, routeKey, routeObject)
	if err != nil {
		return err
	}
	var destinationRegistry string
	err = t.jq.Query(`.status.ingress[]?.host`, routeObject, &destinationRegistry)
	if err != nil {
		return err
	}
	if destinationRegistry == "" {
		return fmt.Errorf(
			"failed to mirror images for cluster '%s' because internal registry "+
				"route doesn't have a host",
			t.cluster.Name,
		)
	}
	t.logger.V(1).Info(
		"Found destination registry",
		"registry", destinationRegistry,
	)

	// Find the CA of the destination registry and write it to the temporary directory:
	registryTool, err := internal.NewRegistryTool().
		SetLogger(t.logger).
		SetClient(t.client).
		Build()
	if err != nil {
		return err
	}
	registryCA, err := registryTool.FetchCA(destinationRegistry)
	if err != nil {
		return err
	}
	registryCAFile := filepath.Join(tmpDir, "oc-mirror-ca.pem")
	err = os.WriteFile(registryCAFile, registryCA, 0600)
	if err != nil {
		return err
	}

	// Generate the configuration file:
	engine, err := templating.NewEngine().
		SetLogger(t.logger).
		SetFS(templatesFS).
		SetDir("templates").
		Build()
	if err != nil {
		return err
	}
	configBuffer := &bytes.Buffer{}
	err = engine.Execute(configBuffer, "oc-mirror-config.yaml", map[string]any{
		"DestinationRegistry":     destinationRegistry,
		"OCPVersion":              t.ocpVersion,
		"ODFVersion":              t.odfVersion,
		"RedhatOperatorsIndex":    t.redhatOperatorsIndex,
		"CertifiedOperatorsIndex": t.certifiedOperatorsIndex,
	})
	if err != nil {
		return err
	}
	configBytes := configBuffer.Bytes()
	configFile := filepath.Join(tmpDir, "oc-mirror-config.yaml")
	err = os.WriteFile(configFile, configBytes, 0600)
	if err != nil {
		return err
	}
	t.logger.V(1).Info(
		"Generated configuration file",
		"file", configFile,
		"text", string(configBytes),
	)

	// Prepare the environment for the mirroring tool so that it will find the credentials and
	// the CA certificates needed to connect to the registry:
	mirrorEnv, err := environment.New().
		SetEnv(os.Environ()...).
		SetVar("XDG_RUNTIME_DIR", tmpDir).
		SetVar("SSL_CERT_FILE", registryCAFile).
		Build()
	if err != nil {
		return err
	}
	pullSecretObject := &corev1.Secret{}
	pullSecretKey := clnt.ObjectKey{
		Namespace: "openshift-config",
		Name:      "pull-secret",
	}
	err = t.client.Get(ctx, pullSecretKey, pullSecretObject)
	if err != nil {
		return err
	}
	authBytes, ok := pullSecretObject.Data[".dockerconfigjson"]
	if !ok {
		return fmt.Errorf(
			"failed to update pull secret for cluster '%s' because secret '%s' "+
				"doesn't contain the '.dockerconfigjson' key",
			t.cluster.Name, pullSecretKey,
		)
	}
	containersDir := filepath.Join(tmpDir, "containers")
	err = os.Mkdir(containersDir, 0700)
	if err != nil {
		return err
	}
	authFile := filepath.Join(containersDir, "auth.json")
	err = os.WriteFile(authFile, authBytes, 0600)
	if err != nil {
		return err
	}
	t.logger.V(1).Info(
		"Generated auth file",
		"file", authFile,
		"!text", string(authBytes),
	)

	// Run the mirroring tool:
	mirrorBinary, err := exec.LookPath("oc-mirror")
	if err != nil {
		return err
	}
	mirrorCmd := exec.Cmd{
		Env:  mirrorEnv,
		Path: mirrorBinary,
		Args: []string{
			"oc-mirror",
			"--config", configFile,
			"--max-per-registry", "50",
			"--ignore-history",
			"--source-skip-tls",
			"--dest-skip-tls",
			"--skip-cleanup",
			fmt.Sprintf("docker://%s/ztpfw", destinationRegistry),
		},
		Stdin:  &bytes.Buffer{},
		Stdout: t.tool.Out(),
		Stderr: t.tool.Err(),
	}
	t.logger.V(1).Info(
		"Running mirror tool",
		"env", mirrorCmd.Env,
		"path", mirrorCmd.Path,
		"args", mirrorCmd.Args,
	)
	err = mirrorCmd.Run()
	processState := mirrorCmd.ProcessState
	if processState != nil {
		t.logger.V(1).Info(
			"Mirror tool finished",
			"code", processState.ExitCode(),
		)
	} else {
		t.logger.V(1).Info("Mirror tool finished without exit code")
	}
	if err != nil {
		return err
	}
	return nil
}
