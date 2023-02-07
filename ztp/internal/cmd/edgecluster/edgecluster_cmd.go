/*
Copyright 2022 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package edgecluster

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Cobra creates and returns the `edgecluster` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:   "edgecluster",
		Short: "Creates an edge cluster",
		Args:  cobra.NoArgs,
		RunE:  c.Run,
	}
	flags := result.Flags()
	flags.StringVar(
		&c.flags.config,
		"config",
		"",
		"Location of the configuration file. The default is to use the file specified "+
			"in the 'EDGECLUSTERS_FILE' environment variable.",
	)
	flags.DurationVar(
		&c.flags.wait,
		"wait",
		60*time.Minute,
		"Time to wait till the clusters are ready. Set to zero to disable waiting.",
	)
	return result
}

// Command contains the data and logic needed to run the `edgecluster` command.
type Command struct {
	flags struct {
		config string
		wait   time.Duration
	}
	logger    logr.Logger
	env       map[string]string
	jq        *internal.JQ
	tool      *internal.Tool
	config    models.Config
	client    clnt.WithWatch
	templates *templating.Engine
	renderer  *internal.Renderer
}

// NewCommand creates a new runner that knows how to execute the `edgecluster` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `edgecluster` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.tool = internal.ToolFromContext(ctx)

	// Get the environment:
	c.env = c.tool.Env()

	// Create the JQ object:
	c.jq, err = internal.NewJQ().
		SetLogger(c.logger).
		Build()
	if err != nil {
		return fmt.Errorf("failed to create JQ object: %v", err)
	}

	// Load the templates:
	c.templates, err = templating.NewEngine().
		SetLogger(c.logger).
		SetFS(internal.DataFS).
		SetDir("data/prd/templates").
		Build()
	if err != nil {
		return fmt.Errorf("failed to parse the templates: %v", err)
	}
	templates := []string{}
	for _, name := range c.templates.Names() {
		if strings.HasPrefix(name, "objects/") && strings.HasSuffix(name, ".yaml") {
			templates = append(templates, name)
		}
	}

	// Load the configuration:
	err = c.loadConfiguration()
	if err != nil {
		return err
	}

	// Create the client for the API:
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetEnv(c.env).
		Build()
	if err != nil {
		return fmt.Errorf(
			"failed to create API client: %v",
			err,
		)
	}

	// Enrich the configuration:
	enricher, err := internal.NewEnricher().
		SetLogger(c.logger).
		SetEnv(c.env).
		SetClient(c.client).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create enricher: %v",
			err,
		)
		return internal.ExitError(1)
	}
	err = enricher.Enrich(ctx, &c.config)
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to enrich configuration: %v",
			err,
		)
		return internal.ExitError(1)
	}

	// Create the renderer:
	c.renderer, err = internal.NewRenderer().
		SetLogger(c.logger).
		SetTemplates(c.templates, templates...).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create renderer: %v",
			err,
		)
		return internal.ExitError(1)
	}

	// Deploy the clusters:
	for _, cluster := range c.config.Clusters {
		fmt.Fprintf(c.tool.Out(), "Deploying cluster '%s'\n", cluster.Name)
		err = c.deploy(ctx, &cluster)
		if err != nil {
			return fmt.Errorf(
				"failed to deploy cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	// Wait for clusters to be ready:
	if c.flags.wait != 0 {
		fmt.Fprintf(
			c.tool.Out(),
			"Waiting up to %s for clusters to be ready\n",
			c.flags.wait,
		)
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, c.flags.wait)
		defer cancel()
		for _, cluster := range c.config.Clusters {
			err = c.wait(ctx, &cluster)
			if os.IsTimeout(err) {
				fmt.Fprintf(
					c.tool.Out(),
					"Clusters aren't ready after waiting for %s\n",
					c.flags.wait,
				)
				return internal.ExitError(1)
			}
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *Command) loadConfiguration() error {
	// Get the name of the configuration file:
	file := c.flags.config
	if file == "" {
		var ok bool
		file, ok = c.env["EDGECLUSTERS_FILE"]
		if !ok {
			fmt.Fprintf(
				c.tool.Out(),
				"Can't load configuration because the '--config' flag is "+
					"empty and the 'EDGECLUSTERS_FILE' environment "+
					"variable isn't set",
			)
			return internal.ExitError(1)
		}
	}

	// Check that the file exists. Note that this is also checked later by the loader, but this
	// way we can generate a nicer error message in most cases.
	_, err := os.Stat(file)
	if os.IsNotExist(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"Configuration file '%s' doesn't exist\n",
			file,
		)
		return internal.ExitError(1)
	}

	// Load the configuration:
	c.config, err = internal.NewConfigLoader().
		SetLogger(c.logger).
		SetSource(file).
		Load()
	if err != nil {
		fmt.Fprintf(
			c.tool.Out(),
			"Failed to load configuration file '%s': %v\n",
			file, err,
		)
		return internal.ExitError(1)
	}

	return nil
}

func (c *Command) deploy(ctx context.Context, cluster *models.Cluster) error {
	// Render the objects:
	objects, err := c.renderer.Render(ctx, map[string]any{
		"Cluster": cluster,
	})
	if err != nil {
		return err
	}
	c.logger.V(2).Info(
		"Rendered objects",
		"objects", objects,
	)

	// Create the objects:
	for _, object := range objects {
		err = c.apply(ctx, object)
		if err != nil {
			return err
		}
	}

	return nil
}

func (c *Command) apply(ctx context.Context, object clnt.Object) error {
	// Add the label that identifies the object as created by us:
	labels := object.GetLabels()
	if labels == nil {
		labels = map[string]string{}
	}
	labels["ztp"] = "true"
	object.SetLabels(labels)

	// Create the object:
	err := c.client.Create(ctx, object)
	if errors.IsAlreadyExists(err) {
		return nil
	}
	return err
}

func (c *Command) wait(ctx context.Context, cluster *models.Cluster) error {
	waitTasks := []func(context.Context, *models.Cluster) error{
		c.waitHosts,
		c.waitInstall,
	}
	for _, waitTask := range waitTasks {
		err := waitTask(ctx, cluster)
		if err != nil {
			return err
		}
	}
	return nil
}

func (c *Command) waitHosts(ctx context.Context, cluster *models.Cluster) error {
	fmt.Fprintf(
		c.tool.Out(),
		"Waiting for hosts of cluster '%s' to be provisioned\n",
		cluster.Name,
	)

	// First retrieve the list of hosts in the namespace of the cluster and construct a set with
	// the names of the hosts that are not yet provisioned.
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.BareMetalHostListGVK)
	err := c.client.List(ctx, list, clnt.InNamespace(cluster.Name))
	if err != nil {
		return err
	}
	pending := map[string]bool{}
	for _, item := range list.Items {
		pending[item.GetName()] = true
	}

	// Now watch for changes in the hosts, remove them from the pending set when the status is
	// `provisioned` and stop when the pending set is empty.
	watch, err := c.client.Watch(ctx, list, clnt.InNamespace(cluster.Name))
	if err != nil {
		return err
	}
	defer watch.Stop()
	for event := range watch.ResultChan() {
		object, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		var state string
		err = c.jq.Query(
			`try .status.provisioning.state`,
			object.Object, &state,
		)
		if err != nil {
			return err
		}
		if state == "provisioned" {
			name := object.GetName()
			fmt.Fprintf(
				c.tool.Out(),
				"Host '%s' of cluster '%s' is provisioned\n",
				name, cluster.Name,
			)
			delete(pending, name)
			if len(pending) == 0 {
				break
			}
		}
	}
	return nil
}

func (c *Command) waitInstall(ctx context.Context, cluster *models.Cluster) error {
	fmt.Fprintf(
		c.tool.Out(),
		"Waiting for installation of cluster '%s' to be completed\n",
		cluster.Name,
	)

	// Watch the agent cluster install till the status is `ready`:
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.AgentClusterIntallGVK)
	watch, err := c.client.Watch(
		ctx,
		list,
		clnt.InNamespace(cluster.Name),
		clnt.MatchingFields{
			"metadata.name": cluster.Name,
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	for event := range watch.ResultChan() {
		var status string
		err = c.jq.Query(
			`try .status.conditions[] | select(.type == "Completed") | .status`,
			event.Object, &status,
		)
		if err != nil {
			return err
		}
		if status == "ready" {
			fmt.Fprintf(
				c.tool.Out(),
				"Cluster '%s' is installed\n",
				cluster.Name,
			)
			break
		}
	}
	return nil
}
