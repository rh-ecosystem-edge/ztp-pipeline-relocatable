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
	"strings"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Cobra creates and returns the `edgecluster` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	return &cobra.Command{
		Use:   "edgecluster",
		Short: "Creates an edge cluster",
		Args:  cobra.NoArgs,
		RunE:  c.Run,
	}
}

// Command contains the data and logic needed to run the `edgecluster` command.
type Command struct {
	logger    logr.Logger
	env       map[string]string
	tool      *internal.Tool
	config    models.Config
	client    clnt.WithWatch
	templates *templating.Engine
	enricher  *internal.Enricher
	renderer  *internal.Renderer
}

// NewCommand creates a new runner that knows how to execute the `edgecluster` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `edgecluster` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) (err error) {
	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.tool = internal.ToolFromContext(ctx)

	// Get the environment:
	c.env = c.tool.Env()

	// Load the templates:
	fmt.Fprintf(c.tool.Out(), "Loading templates\n")
	c.templates, err = templating.NewEngine().
		SetLogger(c.logger).
		SetFS(internal.DataFS).
		SetDir("data/prd/templates").
		Build()
	if err != nil {
		err = fmt.Errorf("failed to parse the templates: %v", err)
		return
	}
	templates := []string{}
	for _, name := range c.templates.Names() {
		if strings.HasPrefix(name, "objects/") && strings.HasSuffix(name, ".yaml") {
			templates = append(templates, name)
		}
	}

	// Load the configuration:
	fmt.Fprintf(c.tool.Out(), "Loading configuration\n")
	file, ok := c.env["EDGECLUSTERS_FILE"]
	if !ok {
		err = fmt.Errorf(
			"failed to load configuration because environment variable " +
				"'EDGECLUSTERS_FILE' isn't defined",
		)
		return
	}
	c.config, err = internal.NewConfigLoader().
		SetLogger(c.logger).
		SetSource(file).
		Load()
	if err != nil {
		err = fmt.Errorf(
			"failed to load configuration from file '%s': %v",
			file, err,
		)
		return
	}

	// Create the client for the API:
	fmt.Fprintf(c.tool.Out(), "Creating API client\n")
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetEnv(c.env).
		Build()
	if err != nil {
		err = fmt.Errorf(
			"failed to create API client: %v",
			err,
		)
		return
	}

	// Create the enricher and the renderer:
	c.enricher, err = internal.NewEnricher().
		SetLogger(c.logger).
		SetEnv(c.env).
		SetClient(c.client).
		Build()
	if err != nil {
		err = fmt.Errorf(
			"failed to create enricher: %v",
			err,
		)
		return
	}
	c.renderer, err = internal.NewRenderer().
		SetLogger(c.logger).
		SetTemplates(c.templates, templates...).
		Build()
	if err != nil {
		err = fmt.Errorf(
			"failed to create renderer: %v",
			err,
		)
		return
	}

	// Deploy the clusters:
	for _, cluster := range c.config.Clusters {
		fmt.Fprintf(c.tool.Out(), "Deploying cluster '%s'\n", cluster.Name)
		err = c.deploy(ctx, &cluster)
		if err != nil {
			err = fmt.Errorf(
				"failed to deploy cluster '%s': %v",
				cluster.Name, err,
			)
			return
		}
	}

	return
}

func (c *Command) deploy(ctx context.Context, cluster *models.Cluster) error {
	// Render the objects:
	fmt.Fprintf(c.tool.Out(), "Rendering objects for cluster '%s'\n", cluster.Name)
	err := c.enricher.Enrich(ctx, cluster)
	if err != nil {
		return err
	}
	c.logger.V(2).Info(
		"Enriched cluster",
		"cluster", cluster,
	)
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
	fmt.Fprintf(c.tool.Out(), "Creating objects for cluster '%s'\n", cluster.Name)
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
	if err != nil {
		return err
	}

	return nil
}
