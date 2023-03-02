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

package lso

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"sort"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"golang.org/x/crypto/ssh"
	"golang.org/x/exp/slices"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Cobra creates and returns the `create lso` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:     "lso",
		Aliases: []string{"lsos"},
		Short:   "Deploys local storage operator",
		Args:    cobra.NoArgs,
		RunE:    c.Run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	_ = flags.Bool(
		wipeFlagName,
		false,
		"Enable or disable wiping the storage disks of the nodes of the cluster. This "+
			"is disabled by default to prevent accidentally wiping the disks of nodes "+
			"in testing and development environments. In production environments it "+
			"should be explicitly enabled.",
	)
	return result
}

// Command contains the data and logic needed to run the `create lso` command.
type Command struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// Task contains the information necessary to complete each of the tasks that this command runs, in
// particular it contains the reference to the cluster it works with, so that it isn't necessary to
// pass this reference around all the time.
type Task struct {
	parent  *Command
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	cluster *models.Cluster
	client  *internal.Client
}

// NewCommand creates a new runner that knows how to execute the `create lso` command.
func NewCommand() *Command {
	return &Command{}
}

// Run runs the `create lso` command.
func (c *Command) Run(cmd *cobra.Command, argv []string) error {
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
		task := &Task{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			flags:   c.flags,
			jq:      c.jq,
			console: c.console,
			cluster: cluster,
		}
		err = task.Run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create local storage operator for cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	return nil
}

func (t *Task) Run(ctx context.Context) error {
	var err error

	// Check that the Kubeconfig is available:
	if t.cluster.Kubeconfig == nil {
		return errors.New("kubeconfig isn't available")
	}

	// Check that the SSH key is available:
	if t.cluster.SSH.PrivateKey == nil {
		return fmt.Errorf("SSH key isn't available")
	}

	// Check that there is at least one control plane node:
	nodes := t.cluster.ControlPlaneNodes()
	if len(nodes) == 0 {
		return fmt.Errorf("there are no control plane nodes")
	}

	// Check that the IP addreses of all the control plane nodes are available. This is
	// necessary because we are going to connect to those nodes via SSH to wipe the disks.
	var missing []string
	for _, node := range nodes {
		if node.ExternalIP == nil {
			missing = append(missing, node.Name)
		}
	}
	if len(missing) > 0 {
		if len(missing) > 1 {
			return fmt.Errorf(
				"IP addresses of nodes %s aren't available",
				logging.All(missing),
			)
		}
		return fmt.Errorf(
			"IP address of node '%s' isn't available",
			missing[0],
		)
	}

	// Currently we assume that all the control lane nodes nodes have the same storage disks, so
	// we need to verify it:
	disks0 := slices.Clone(nodes[0].StorageDisks)
	sort.Strings(disks0)
	for i := 1; i < len(nodes); i++ {
		disksI := slices.Clone(nodes[i].StorageDisks)
		sort.Strings(disksI)
		if !slices.Equal(disks0, disksI) {
			return fmt.Errorf(
				"all control plane nodes should have the same storage disks, "+
					"but node '%s' has %s and node '%s' has %s",
				nodes[0].Name, logging.All(disks0),
				nodes[i].Name, logging.All(disksI),
			)
		}
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

	// Wipe the disks of the control plane nodes:
	wipe, err := t.flags.GetBool(wipeFlagName)
	if err != nil {
		return fmt.Errorf(
			"failed to get the value of the '--%s' flag",
			wipeFlagName,
		)
	}
	if wipe {
		for _, node := range nodes {
			t.console.Info(
				"Wiping disks of node '%s' of cluster '%s'",
				node.Name, t.cluster.Name,
			)
			err = t.wipeDisks(ctx, node)
			if err != nil {
				return err
			}
		}
	} else {
		t.console.Warn(
			"Will not wipe the disks of cluster '%s', to enable it add "+
				" the '--%s=true' flag",
			t.cluster.Name, wipeFlagName,
		)
	}

	// Deploy the operator:
	err = t.deployLSO(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (t *Task) wipeDisks(ctx context.Context, node *models.Node) error {
	// Create a logger specific for this node:
	logger := t.logger.WithValues("node", node.Name)

	// Parse the key:
	key, err := ssh.ParsePrivateKey(t.cluster.SSH.PrivateKey)
	if err != nil {
		return err
	}

	// Create the SSH session:
	server := fmt.Sprintf("%s:22", node.ExternalIP.Address)
	client, err := ssh.Dial("tcp", server, &ssh.ClientConfig{
		User: "core",
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(key),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	})
	if err != nil {
		return err
	}
	session, err := client.NewSession()
	if err != nil {
		return err
	}
	logger.Info(
		"Created SSH session",
		"server", server,
	)
	defer session.Close()

	// Generate the script:
	engine, err := templating.NewEngine().
		SetLogger(t.logger).
		SetFS(internal.DataFS).
		SetDir("data/lso/scripts").
		Build()
	if err != nil {
		return err
	}
	buffer := &bytes.Buffer{}
	err = engine.Execute(buffer, "wipe.sh", map[string]any{
		"Disks": node.StorageDisks,
	})
	if err != nil {
		return err
	}
	script := buffer.String()
	logger.V(1).Info(
		"Generated script to wipe disks",
		"disks", node.StorageDisks,
		"script", script,
	)

	// Execute the script:
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	session.Stdout = stdout
	session.Stderr = stderr
	err = session.Run(script)
	logger.V(1).Info(
		"Executed script to wipe disks",
		"stdout", stdout.String(),
		"stderr", stderr.String(),
	)
	if err != nil {
		return err
	}

	return nil
}

func (t *Task) deployLSO(ctx context.Context) error {
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
		SetRoot("data/lso/objects").
		Build()
	if err != nil {
		return err
	}

	// Calculate the variables:
	hostnames := t.getHostnames()
	disks := t.getDisks()
	t.logger.Info(
		"Calculated LSO details",
		"hostnames", hostnames,
		"disks", disks,
	)

	// Create the objects:
	objects, err := applier.Render(ctx, map[string]any{
		"Hostnames": hostnames,
		"Disks":     disks,
	})
	if err != nil {
		return err
	}
	err = applier.ApplyObjects(ctx, objects)
	if err != nil {
		return err
	}

	// Find the volume:
	var volume *unstructured.Unstructured
	for _, object := range objects {
		if object.GroupVersionKind() == internal.LocalVolumeGVK {
			volume = object
			break
		}
	}
	if volume == nil {
		return fmt.Errorf("failed to find created local volume")
	}

	// Wait till the volume is available:
	return t.waitVolume(ctx, volume)
}

func (t *Task) getHostnames() []string {
	nodes := t.cluster.ControlPlaneNodes()
	names := make([]string, len(nodes))
	for i, node := range nodes {
		names[i] = node.Hostname
	}
	sort.Strings(names)
	return names
}

func (t *Task) getDisks() []string {
	// Note that currently the configuration assumes that all the nodes have the same storage
	// disks, and that is validated before this point, so we can just get the storage disks of
	// the first control plane node.
	disks := t.cluster.ControlPlaneNodes()[0].StorageDisks
	sort.Strings(disks)
	return disks
}

func (t *Task) waitVolume(ctx context.Context, volume *unstructured.Unstructured) error {
	t.console.Info(
		"Waiting for local volume '%s' of cluster '%s' to be available",
		volume, t.cluster.Name,
	)
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.LocalVolumeGVK)
	watch, err := t.client.Watch(
		ctx, list,
		clnt.InNamespace(volume.GetNamespace()),
		clnt.MatchingFields{
			"metadata.name": volume.GetName(),
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	for event := range watch.ResultChan() {
		object, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		var available string
		err = t.jq.Query(
			`.status.conditions[]? | select(.type == "Available") | .status`,
			object.Object, &available,
		)
		if err != nil {
			return err
		}
		if available == "True" {
			t.console.Info(
				"Local volume '%s' of cluster '%s' is now available",
				volume, t.cluster.Name,
			)
			break
		}
	}
	return nil
}

// Names of command line flags:
const (
	wipeFlagName = "wipe"
)
