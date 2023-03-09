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
	"fmt"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Delete creates and returns the `delete metallb` command.
func Delete() *cobra.Command {
	c := NewDeleteCommand()
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
	_ = flags.Bool(
		crdsFlagName,
		false,
		"Enabled or disables deletion of the custom resource definitions of the "+
			"'metalb.io' and 'nmstate.io' groups that are created when the metal "+
			"load balancer is created. This is itended for use in testing and "+
			"developments environments and shouldn't be used in production "+
			"environments.",
	)
	return result
}

// DeleteCommand contains the data and logic needed to run the `delete metallb` command.
type DeleteCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
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

// NewDeleteCommand creates a new runner that knows how to execute the `delete metallb` command.
func NewDeleteCommand() *DeleteCommand {
	return &DeleteCommand{}
}

// Run runs the `delete metallb` command.
func (c *DeleteCommand) Run(cmd *cobra.Command, argv []string) error {
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
				"Failed to delete balancer for cluster '%s': %v",
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
		SetFlags(t.flags).
		SetKubeconfig(t.cluster.Kubeconfig).
		SetSSHServer(sshIP.Address.String()).
		SetSSHUser("core").
		SetSSHKey(t.cluster.SSH.PrivateKey).
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
		SetRoot("data/metallb").
		SetDir("objects").
		Build()
	if err != nil {
		return err
	}

	// Delete the objects:
	err = applier.Delete(ctx, map[string]any{
		"Cluster": t.cluster,
	})
	if err != nil {
		return err
	}

	// Deleting the CRDs:
	crds, err := t.flags.GetBool(crdsFlagName)
	if err != nil {
		return err
	}
	if crds {
		t.console.Warn("CRDs in groups 'metallb.io' and 'mnstate.io' will be deleted")
		err = t.deleteCRDGroup(ctx, "metallb.io")
		if err != nil {
			return err
		}
		err = t.deleteCRDGroup(ctx, "nmstate.io")
		if err != nil {
			return err
		}
	}

	return nil
}

func (t *DeleteTask) deleteCRDGroup(ctx context.Context, group string) error {
	n, err := t.client.DeleteCRDGroup(ctx, group)
	if err != nil {
		return err
	}
	switch {
	case n == 0:
		t.console.Info(
			"There are CRDs to delete in group '%s' in cluster '%s'",
			group, t.cluster.Name,
		)
	case n == 1:
		t.console.Info(
			"Deleted one CRD in group '%s' in cluster '%s'",
			group, t.cluster.Name,
		)
	default:
		t.console.Info(
			"Deleted %d CRDs in group '%s' in cluster '%s",
			n, group, t.cluster.Name,
		)
	}
	return nil
}

// Names of command line flags:
const (
	crdsFlagName = "crds"
)
