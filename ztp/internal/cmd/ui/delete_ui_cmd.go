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

package ui

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Delete creates and returns the `delete ui` command.
func Delete() *cobra.Command {
	c := NewDeleteCommand()
	result := &cobra.Command{
		Use:     "ui",
		Aliases: []string{"uis"},
		Short:   "Deletes the user interface componnets",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// DeleteCommand contains the data and logic needed to run the `delete ui` command.
type DeleteCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// DeleteTask contains the information necessary to complete each of the tasks that this command
// runs, in particular it contains the reference to the cluster it works with, so that it isn't
// necessary to pass this reference around all the time.
type DeleteTask struct {
	parent  *DeleteCommand
	logger  logr.Logger
	flags   *pflag.FlagSet
	console *internal.Console
	cluster *models.Cluster
	client  *internal.Client
}

// NewDeleteCommand creates a new runner that knows how to execute the `delete ui` command.
func NewDeleteCommand() *DeleteCommand {
	return &DeleteCommand{}
}

// Run runs the `delete ui` command.
func (c *DeleteCommand) Run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.console = internal.ConsoleFromContext(ctx)

	// Save the flags:
	c.flags = cmd.Flags()

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
		task := &DeleteTask{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			flags:   c.flags,
			console: c.console,
			cluster: cluster,
		}
		err = task.Run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to delete UI components for cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	return nil
}

func (t *DeleteTask) Run(ctx context.Context) error {
	var err error

	// Check that the Kubeconfig is available:
	if t.cluster.Kubeconfig == nil {
		return errors.New("kubeconfig isn't available")
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
		SetFS(internal.DataFS).
		SetRoot("data/ui").
		SetDir("objects").
		Build()
	if err != nil {
		return err
	}

	// Delete the objects:
	return applier.Delete(ctx, nil)
}
