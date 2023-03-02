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

package metallb

import (
	"context"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Cobra creates and returns the `delete metallb` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:     "metallb",
		Aliases: []string{"metallbs"},
		Short:   "Deletes metal load balancers",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// Command contains the data and logic needed to run the `delete metallb` command.
type Command struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// NewCommand creates a new runner that knows how to execute the `delete metallb` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `delete metallb` command.
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
			"Failed to create API client: %v",
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

	// Delete the load balancers:
	for _, cluster := range c.config.Clusters {
		err = c.deleteLB(ctx, cluster)
		if err != nil {
			c.console.Error(
				"Failed to delete load balancer for cluster '%s': %v",
				cluster.Name, err,
			)
			return exit.Error(1)
		}
	}

	return nil
}

func (c *Command) deleteLB(ctx context.Context, cluster *models.Cluster) error {
	// Check that the Kubeconfig is available:
	if cluster.Kubeconfig == nil {
		c.console.Error(
			"Kubeconfig for cluster '%s' isn't available",
			cluster.Name,
		)
		return exit.Error(1)
	}

	// Check that the SSH key is available:
	if cluster.SSH.PrivateKey == nil {
		c.console.Error(
			"SSH key for cluster '%s' isn't available",
			cluster.Name,
		)
		return exit.Error(1)
	}

	// Find the first control plane node that has an external IP:
	var sshIP *models.IP
	for _, node := range cluster.ControlPlaneNodes() {
		if node.ExternalIP != nil {
			sshIP = node.ExternalIP
			break
		}
	}
	if sshIP == nil {
		c.console.Error(
			"Failed to find SSH host for cluster '%s' because there is no control "+
				"plane node that has an external IP address",
			cluster.Name,
		)
		return exit.Error(1)
	}

	// Create the client using a dialer that creates connections tunnelled via the SSH
	// connection to the cluster:
	client, err := internal.NewClient().
		SetLogger(c.logger).
		SetFlags(c.flags).
		SetKubeconfig(cluster.Kubeconfig).
		SetSSHServer(sshIP.Address.String()).
		SetSSHUser("core").
		SetSSHKey(cluster.SSH.PrivateKey).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create API client: %v",
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
			"Failed to create listener: %v",
			err,
		)
		return exit.Error(1)
	}
	applier, err := internal.NewApplier().
		SetLogger(c.logger).
		SetListener(listener.Func).
		SetClient(client).
		SetFS(internal.DataFS).
		SetRoot("data/metallb").
		SetDir("objects").
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create applier: %v",
			err,
		)
		return exit.Error(1)
	}

	// Delete the objects:
	return applier.Delete(ctx, map[string]any{
		"Cluster": cluster,
	})
}
