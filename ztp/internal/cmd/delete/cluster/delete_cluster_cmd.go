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

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
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
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// Command contains the data and logic needed to run the `delete cluster` command.
type Command struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	console *internal.Console
	config  *models.Config
	client  *internal.Client
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
	c.console = internal.ConsoleFromContext(ctx)

	// Save the flags:
	c.flags = cmd.Flags()

	// Load the configuration:
	c.config, err = config.NewLoader().
		SetLogger(c.logger).
		SetFlags(cmd.Flags()).
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
	defer c.client.Close()

	// Enrich the configuration:
	enricher, err := internal.NewEnricher().
		SetLogger(c.logger).
		SetClient(c.client).
		SetFlags(cmd.Flags()).
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

	// Create the applier:
	listener, err := internal.NewApplierListener().
		SetLogger(c.logger).
		SetConsole(c.console).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create applier listener: %v",
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
		c.console.Error(
			"Failed to create applier: %v",
			err,
		)
		return exit.Error(1)
	}

	// Delete the clusters:
	for _, cluster := range c.config.Clusters {
		err = c.delete(ctx, cluster)
		if err != nil {
			c.console.Error(
				"Failed to delete cluster '%s': %v",
				cluster.Name, err,
			)
			return exit.Error(1)
		}
	}

	return nil
}

func (c *Command) delete(ctx context.Context, cluster *models.Cluster) error {
	// The cluster deployment can't be deleted directly because Hive will then delete the
	// namespace, and with the namespace terminating it isn't possible to delete other objects
	// that create things as part of the deletion process. In particular the process to delete
	// bare metal hosts needs to create `preprovisioningimages` inside the namespace. To address
	// that remove the cluster deployment from the list of objects to delete, and let Kubernetes
	// delete it when the namespace is deleted.
	objects, err := c.applier.Render(ctx, map[string]any{
		"Cluster": cluster,
	})
	if err != nil {
		return err
	}
	deleteable := make([]*unstructured.Unstructured, 0, len(objects)-1)
	for _, object := range objects {
		if object.GroupVersionKind() == internal.ClusterDeploymentGVK {
			continue
		}
		deleteable = append(deleteable, object)
	}
	return c.applier.DeleteObjects(ctx, deleteable)
}
