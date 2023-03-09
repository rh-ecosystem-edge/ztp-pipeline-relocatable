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
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Create creates and returns the `create metallb` command.
func Create() *cobra.Command {
	c := NewCreateCommand()
	result := &cobra.Command{
		Use:     "metallb",
		Aliases: []string{"metallbs"},
		Short:   "Creates metal load balancers",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	_ = flags.DurationP(
		waitFlagName,
		"w",
		10*time.Minute,
		"Time to wait till the API endpoints are reachable. Set to zero to disable "+
			"waiting.",
	)
	return result
}

// CreateCommand contains the data and logic needed to run the `create metallb` command.
type CreateCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
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
	console *internal.Console
	cluster *models.Cluster
	client  *internal.Client
}

// NewCreateCommand creates a new runner that knows how to execute the `create metallb` command.
func NewCreateCommand() *CreateCommand {
	return &CreateCommand{}
}

// Run runs the `create metallb` command.
func (c *CreateCommand) Run(cmd *cobra.Command, argv []string) error {
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
		task := &CreateTask{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			flags:   c.flags,
			console: c.console,
			cluster: cluster,
		}
		err = task.Run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create load balancer for cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	// Wait for the API endpoints of the clusters to be reachable:
	wait, err := c.flags.GetDuration(waitFlagName)
	if err != nil {
		c.console.Error(
			"Failed to get value of flag '--%s': %v",
			waitFlagName, err,
		)
		return exit.Error(1)
	}
	if wait != 0 {
		c.console.Info(
			"Waiting up to %s for API endpoints to be reachable",
			wait,
		)
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, wait)
		defer cancel()
		for _, cluster := range c.config.Clusters {
			c.console.Info(
				"Waiting for API endpoint of cluster '%s' to be reachable",
				cluster.Name,
			)
			err = c.wait(ctx, cluster)
			if os.IsTimeout(err) {
				c.console.Error(
					"API endpoints aren't reachable after waiting for %s",
					wait,
				)
				return exit.Error(1)
			}
			if err != nil {
				return err
			}
			c.console.Info(
				"API endpoint of cluster '%s' is now reachable",
				cluster.Name,
			)
		}
	}

	return nil
}

func (t *CreateTask) Run(ctx context.Context) error {
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

	// Create the objects:
	return applier.Apply(ctx, map[string]any{
		"Cluster": t.cluster,
	})
}

func (t *CreateCommand) wait(ctx context.Context, cluster *models.Cluster) error {
	// Check that the Kubeconfig is available:
	if cluster.Kubeconfig == nil {
		return fmt.Errorf(
			"kubeconfig for cluster '%s' isn't available",
			cluster.Name,
		)
	}

	// Create an API client that connects directly, without the SSH tunnel:
	client, err := internal.NewClient().
		SetLogger(t.logger).
		SetFlags(t.flags).
		SetKubeconfig(cluster.Kubeconfig).
		Build()
	if err != nil {
		return err
	}
	defer client.Close()

	// Try a simple operation till it succeeds:
	settings := backoff.NewExponentialBackOff()
	settings.MaxInterval = time.Minute
	settings.MaxElapsedTime = 0
	operation := func() error {
		object := &corev1.Namespace{}
		key := clnt.ObjectKey{
			Name: "kube-public",
		}
		return client.Get(ctx, key, object)
	}
	notify := func(err error, delay time.Duration) {
		t.logger.V(1).Info(
			"API check failed, will retry",
			"error", err,
			"delay", delay,
		)
	}
	return backoff.RetryNotify(
		operation,
		backoff.WithContext(settings, ctx),
		notify,
	)
}

// Names of the command line flags:
const (
	waitFlagName = "wait"
)
