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
	"os"
	"path/filepath"
	"time"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/labels"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Cobra creates and returns the `create cluster` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:     "cluster",
		Aliases: []string{"clusters"},
		Short:   "Creates clusters",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	flags.StringVarP(
		&c.flags.output,
		"output",
		"o",
		"",
		"Base directory for output files, including the generated SSH keys. If not specified then "+
			"no output files are generated.",
	)
	flags.DurationVarP(
		&c.flags.wait,
		"wait",
		"w",
		60*time.Minute,
		"Time to wait till the clusters are ready. Set to zero to disable waiting.",
	)
	return result
}

// Command contains the data and logic needed to run the `create cluster` command.
type Command struct {
	flags struct {
		config string
		output string
		wait   time.Duration
	}
	logger  logr.Logger
	jq      *jq.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
	applier *internal.Applier
}

// NewCommand creates a new runner that knows how to execute the `create cluster` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `create cluster` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.console = internal.ConsoleFromContext(ctx)

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
			"Failed to create listener: %v",
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

	// Deploy the clusters:
	for _, cluster := range c.config.Clusters {
		err = c.deploy(ctx, cluster)
		if err != nil {
			c.console.Error(
				"Failed to deploy cluster '%s': %v",
				cluster.Name, err,
			)
			return exit.Error(1)
		}
	}

	// Write the output files:
	if c.flags.output != "" {
		for _, cluster := range c.config.Clusters {
			err = c.writeOutput(ctx, cluster)
			if err != nil {
				c.console.Error(
					"Failed to write output files for cluster '%s': %v",
					cluster.Name, err,
				)
				return exit.Error(1)
			}
		}
	}

	// Wait for clusters to be ready:
	if c.flags.wait != 0 {
		c.console.Info(
			"Waiting up to %s for clusters to be ready",
			c.flags.wait,
		)
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, c.flags.wait)
		defer cancel()
		for _, cluster := range c.config.Clusters {
			err = c.wait(ctx, cluster)
			if os.IsTimeout(err) {
				c.console.Error(
					"Clusters aren't ready after waiting for %s",
					c.flags.wait,
				)
				return exit.Error(1)
			}
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *Command) deploy(ctx context.Context, cluster *models.Cluster) error {
	return c.applier.Apply(ctx, map[string]any{
		"Cluster": cluster,
	})
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
	c.console.Info(
		"Waiting for hosts of cluster '%s' to be provisioned",
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
			c.console.Info(
				"Host '%s' of cluster '%s' is provisioned",
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
	c.console.Info(
		"Waiting for installation of cluster '%s' to be completed",
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
	state := ""
	for event := range watch.ResultChan() {
		type Data struct {
			State  string `json:"state"`
			Status string `json:"status"`
		}
		var current Data
		err = c.jq.Query(
			`try {
				"state": .status.debugInfo.state,
				"status": .status.conditions[] | select(.type == "Completed") | .status
			}`,
			event.Object, &current,
		)
		if err != nil {
			return err
		}
		if current.State != state {
			c.console.Info(
				"Cluster '%s' moved to state '%s'",
				cluster.Name, current.State,
			)
			state = current.State
		}
		if current.Status == "True" {
			c.console.Info(
				"Cluster '%s' is installed",
				cluster.Name,
			)
			break
		}
	}
	return nil
}

func (c *Command) writeOutput(ctx context.Context, cluster *models.Cluster) error {
	// Create the directory for the cluster files:
	dir := filepath.Join(c.flags.output, cluster.Name)
	err := os.MkdirAll(dir, 0700)
	if err != nil {
		return err
	}

	// Write the SSH sshKeyFile files:
	sshKeyFile := filepath.Join(dir, cluster.Name+"-rsa.key")
	err = os.WriteFile(sshKeyFile, cluster.SSH.PrivateKey, 0600)
	if err != nil {
		return err
	}
	c.console.Info(
		"Wrote SSH private key for cluster '%s' to '%s'",
		cluster.Name, sshKeyFile,
	)
	sshPubFile := filepath.Join(dir, cluster.Name+"-rsa.key.pub")
	err = os.WriteFile(sshPubFile, cluster.SSH.PublicKey, 0600)
	if err != nil {
		return err
	}
	c.console.Info(
		"Wrote SSH public key for cluster '%s' to '%s'",
		cluster.Name, sshPubFile,
	)

	return nil
}
