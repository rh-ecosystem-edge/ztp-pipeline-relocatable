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

package dev

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// SSH creates and returns the `dev ssh` command.
func SSH() *cobra.Command {
	c := NewSSHCommand()
	result := &cobra.Command{
		Use:   "ssh",
		Short: "Connects via SSH to a cluster",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	_ = flags.String(
		sshClusterFlagName,
		"",
		"Name of the cluster. This is optional if there is only one cluster "+
			"in the configuration file.",
	)
	_ = flags.String(
		sshNodeFlagName,
		"",
		"Name of the node. This is optional, the default is to use the first "+
			"node of the cluster.",
	)
	return result
}

// SSHCommand contains the data and logic needed to run the `dev ssh` command.
type SSHCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	tool    *internal.Tool
	console *internal.Console
	client  *internal.Client
	config  *models.Config
	cluster *models.Cluster
	node    *models.Node
}

// NewSSHCommand creates a new runner that knows how to execute the `dev ssh` command.
func NewSSHCommand() *SSHCommand {
	return &SSHCommand{}
}

// run executes the `dev ssh` command.
func (c *SSHCommand) run(cmd *cobra.Command, argv []string) (err error) {
	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.tool = internal.ToolFromContext(ctx)
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

	// Try to find matching cluster and node:
	err = c.selectCluster()
	if err != nil {
		c.console.Error("Failed to select cluster: %s", err)
		return exit.Error(1)
	}
	err = c.selectNode()
	if err != nil {
		c.console.Error("Failed to select node: %s", err)
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

	// Remove all non selected clusters and nodes from the configuration and enrich the rest.
	// This will retrieve the SSH key and the IP address of the node.
	c.console.Info(
		"Collecting information for cluster '%s' and node '%s'",
		c.cluster.Name, c.node.Name,
	)
	c.cluster.Nodes = []*models.Node{c.node}
	c.config.Clusters = []*models.Cluster{c.cluster}
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

	// Run the SSH command:
	err = c.runSSH()
	if err != nil {
		c.console.Error(
			"Failed to run SSH command: %v",
			err,
		)
		return exit.Error(1)
	}

	return nil
}

func (c *SSHCommand) selectCluster() error {
	if len(c.config.Clusters) == 0 {
		return fmt.Errorf("there are not clusters in the configuration")
	}
	name, err := c.flags.GetString(sshClusterFlagName)
	if err != nil {
		return fmt.Errorf("failed to get value of flag '--%s': %w", sshClusterFlagName, err)
	}
	if name != "" {
		c.cluster = c.config.LookupCluster(name)
		if c.cluster == nil {
			return fmt.Errorf(
				"there is no cluster named '%s' in the configuration, try %s",
				name, logging.Any(c.config.ClusterNames()),
			)
		}
	} else {
		if len(c.config.Clusters) > 1 {
			return fmt.Errorf(
				"there are %d clusters in the configuration, use the '--%s' "+
					"option to select %s",
				len(c.config.Clusters),
				sshClusterFlagName,
				logging.Any(c.config.ClusterNames()),
			)
		}
		c.cluster = c.config.Clusters[0]
	}
	return nil
}

func (c *SSHCommand) selectNode() error {
	if len(c.cluster.Nodes) == 0 {
		return fmt.Errorf(
			"there are not nodes in the configuration for cluster '%s'",
			c.cluster.Name,
		)
	}
	name, err := c.flags.GetString(sshNodeFlagName)
	if err != nil {
		return fmt.Errorf("failed go get value of flag '--%s': %w", sshNodeFlagName, err)
	}
	if name != "" {
		c.node = c.cluster.LookupNode(name)
		if c.node == nil {
			return fmt.Errorf(
				"there is no node named '%s' in the configuration for "+
					"cluster '%s', try %s",
				name, c.cluster.Name, logging.Any(c.cluster.NodeNames()),
			)
		}
	} else {
		c.node = c.cluster.Nodes[0]
	}
	return nil
}

func (c *SSHCommand) runSSH() error {
	// Check that the SSH key is available:
	keyBytes := c.cluster.SSH.PrivateKey
	if keyBytes == nil {
		return fmt.Errorf(
			"SSH private key for cluster '%s' isn't available",
			c.cluster.Name,
		)
	}

	// Check that the external IP address of the node is available:
	ip := c.node.ExternalIP
	if ip == nil {
		return fmt.Errorf(
			"IP address for node '%s' isn't available",
			c.node.Name,
		)
	}
	c.console.Info(
		"Using IP '%s' to connect to node '%s'",
		ip.Address, c.node.Name,
	)

	// Create a temporary directory containing the SSH files:
	tmpDir, err := os.MkdirTemp("", "*.ssh")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)
	keyFile := filepath.Join(tmpDir, "key")
	err = os.WriteFile(keyFile, keyBytes, 0600)
	if err != nil {
		return err
	}
	hostsFile := filepath.Join(tmpDir, "hosts")

	// Run the SSH command:
	binary, err := exec.LookPath("ssh")
	if err != nil {
		return err
	}
	args := []string{
		"ssh",
		"-i", keyFile,
		"-o", "UserKnownHostsFile=" + hostsFile,
		"-o", "StrictHostKeyChecking=no",
		"-l", "core",
		c.node.ExternalIP.Address.String(),
	}
	cmd := &exec.Cmd{
		Path:   binary,
		Args:   args,
		Stdin:  c.tool.In(),
		Stdout: c.tool.Out(),
		Stderr: c.tool.Err(),
	}
	return cmd.Run()
}

// Names of the command line flags:
const (
	sshClusterFlagName = "cluster"
	sshNodeFlagName    = "node"
)
