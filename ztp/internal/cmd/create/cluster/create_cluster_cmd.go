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
	"time"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
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

// Command contains the data and logic needed to run the `create cluster` command.
type Command struct {
	flags struct {
		config string
		wait   time.Duration
	}
	logger  logr.Logger
	jq      *internal.JQ
	tool    *internal.Tool
	config  models.Config
	client  clnt.WithWatch
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
	c.tool = internal.ToolFromContext(ctx)

	// Create the JQ object:
	c.jq, err = internal.NewJQ().
		SetLogger(c.logger).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create JQ object: %v\n",
			err,
		)
		return exit.Error(1)
	}

	// Load the configuration:
	err = c.loadConfiguration()
	if err != nil {
		return err
	}

	// Create the client for the API:
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
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
			"Failed to create listener: %v\n",
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

	// Deploy the clusters:
	for _, cluster := range c.config.Clusters {
		err = c.deploy(ctx, cluster)
		if err != nil {
			fmt.Fprintf(
				c.tool.Err(),
				"Failed to deploy cluster '%s': %v\n",
				cluster.Name, err,
			)
			return exit.Error(1)
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
			err = c.wait(ctx, cluster)
			if os.IsTimeout(err) {
				fmt.Fprintf(
					c.tool.Err(),
					"Clusters aren't ready after waiting for %s\n",
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

func (c *Command) loadConfiguration() error {
	// Get the name of the configuration file:
	file := c.flags.config
	if file == "" {
		var ok bool
		file, ok = os.LookupEnv("EDGECLUSTERS_FILE")
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

func (c *Command) deploy(ctx context.Context, cluster *models.Cluster) error {
	return c.applier.Create(ctx, map[string]any{
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
