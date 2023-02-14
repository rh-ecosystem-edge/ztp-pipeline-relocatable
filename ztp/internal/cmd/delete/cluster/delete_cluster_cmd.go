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

package cluster

import (
	"context"
	"fmt"
	"os"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/labels"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Cobra creates and returns the `delete cluster` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:     "cluster",
		Aliases: []string{"clusters"},
		Short:   "Deletes clusters",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	flags.StringVar(
		&c.flags.config,
		"config",
		"",
		"Location of the configuration file. The default is to use the file specified "+
			"in the 'EDGECLUSTERS_FILE' environment variable.",
	)
	return result
}

// Command contains the data and logic needed to run the `delete cluster` command.
type Command struct {
	flags struct {
		config string
	}
	logger  logr.Logger
	env     map[string]string
	tool    *internal.Tool
	config  models.Config
	client  clnt.WithWatch
	applier *internal.Applier
}

// NewCommand creates a new runner that knows how to execute the `delete cluster` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `delete cluster` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.tool = internal.ToolFromContext(ctx)

	// Get the environment:
	c.env = c.tool.Env()

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
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create client: %v\n",
			err,
		)
		return exit.Error(1)
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
			"Failed to create enricher: %v\n",
			err,
		)
		return exit.Error(1)
	}
	err = enricher.Enrich(ctx, &c.config)
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to enrich configuration: %v\n",
			err,
		)
		return exit.Error(1)
	}

	// Create the applier:
	listener, err := internal.NewApplierListener().
		SetLogger(c.logger).
		SetOut(c.tool.Out()).
		SetErr(c.tool.Err()).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create applier listener: %v\n",
			err,
		)
		return exit.Error(1)
	}
	c.applier, err = internal.NewApplier().
		SetLogger(c.logger).
		SetListener(listener.Func).
		SetClient(c.client).
		SetFS(internal.DataFS).
		SetRoot("data/cluster").
		SetDir("objects").
		AddLabel(labels.ZTPFW, "").
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create applier: %v\n",
			err,
		)
		return exit.Error(1)
	}

	// Delete the clusters:
	for _, cluster := range c.config.Clusters {
		err = c.delete(ctx, &cluster)
		if err != nil {
			fmt.Fprintf(
				c.tool.Err(),
				"Failed to delete cluster '%s': %v\n",
				cluster.Name, err,
			)
			return exit.Error(1)
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
			return exit.Error(1)
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
		return exit.Error(1)
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
		return exit.Error(1)
	}

	return nil
}

func (c *Command) delete(ctx context.Context, cluster *models.Cluster) error {
	return c.applier.Delete(ctx, map[string]any{
		"Cluster": cluster,
	})
}