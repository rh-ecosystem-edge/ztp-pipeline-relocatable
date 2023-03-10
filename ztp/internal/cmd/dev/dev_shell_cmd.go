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
	"bytes"
	"errors"
	"fmt"
	"io/fs"
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
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// Shell creates and returns the `dev env` command.
func Shell() *cobra.Command {
	c := NewShellCommand()
	result := &cobra.Command{
		Use: "shell",
		Short: "Runs a shell with environment variables and SSH configuration set to " +
			"use a cluster",
		Args: cobra.NoArgs,
		RunE: c.run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	_ = flags.String(
		shellClusterFlagName,
		"",
		"Name of the cluster. This is optional if there is only one cluster "+
			"in the configuration file.",
	)
	return result
}

// ShellCommand contains the data and logic needed to run the `dev env` command.
type ShellCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	tool    *internal.Tool
	console *internal.Console
	client  *internal.Client
	config  *models.Config
	cluster *models.Cluster
}

// NewShellCommand creates a new runner that knows how to execute the `dev env` command.
func NewShellCommand() *ShellCommand {
	return &ShellCommand{}
}

// run executes the `dev env` command.
func (c *ShellCommand) run(cmd *cobra.Command, argv []string) (err error) {
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

	// Try to find matching cluster:
	err = c.selectCluster()
	if err != nil {
		c.console.Error("Failed to select cluster: %s", err)
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

	// Remove all non selected clusters from the configuration and enrich the rest. This will
	// retrieve the SSH key for the cluster and the IP addresses for the nodes.
	c.console.Info(
		"Collecting information for cluster '%s'",
		c.cluster.Name,
	)
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

	// Run the shell:
	err = c.runShell()
	if err != nil {
		c.console.Error(
			"Failed to run shell: %v",
			err,
		)
		return exit.Error(1)
	}

	return nil
}

func (c *ShellCommand) selectCluster() error {
	if len(c.config.Clusters) == 0 {
		return fmt.Errorf("there are not clusters in the configuration")
	}
	name, err := c.flags.GetString(sshClusterFlagName)
	if err != nil {
		return fmt.Errorf(
			"failed to get value of flag '--%s': %w",
			sshClusterFlagName, err,
		)
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
				shellClusterFlagName,
				logging.Any(c.config.ClusterNames()),
			)
		}
		c.cluster = c.config.Clusters[0]
	}
	return nil
}

func (c *ShellCommand) runShell() error {
	// Check that the shell binary is available:
	shellPath, err := exec.LookPath(shellBinary)
	if err != nil {
		return fmt.Errorf(
			"failed to find the '%s' binary",
			shellBinary,
		)
	}

	// Load the templates:
	templateEngine, err := templating.NewEngine().
		SetLogger(c.logger).
		SetFS(templatesFS).
		SetDir("templates/shell").
		Build()
	if err != nil {
		return err
	}

	// Create a temporary file for the configuration files:
	tmpDir, err := os.MkdirTemp("", "*.shell")
	if err != nil {
		return err
	}
	defer os.Remove(tmpDir)

	// Write the kubeconfig:
	if c.cluster.Kubeconfig != nil {
		kubeconfigPath := filepath.Join(tmpDir, ".kube", "config")
		err = c.writeFile(kubeconfigPath, c.cluster.Kubeconfig, 0400)
		if err != nil {
			return err
		}
		c.console.Info(
			"Kubeconfig is available, you can use 'oc' or 'kubectl' to connect to " +
				"the cluster",
		)
	} else {
		c.console.Warn("Kubeconfig ins't available")
	}

	// Check if the IP addresses of the nodes are available:
	var availableNodes, unavailableNodes []string
	for _, node := range c.cluster.Nodes {
		if node.ExternalIP != nil {
			availableNodes = append(availableNodes, node.Name)
		} else {
			unavailableNodes = append(unavailableNodes, node.Name)
		}
	}
	if len(unavailableNodes) > 0 {
		if len(unavailableNodes) == 1 {
			c.console.Warn(
				"IP address for node '%s' isn't available",
				unavailableNodes[0],
			)
		} else {
			c.console.Warn(
				"IP adresses for nodes %s aren't available",
				logging.All(unavailableNodes),
			)
		}
	}
	if len(availableNodes) > 0 {
		if len(availableNodes) == 1 {
			c.console.Info(
				"You can use 'ssh %[1]s' to connect to node '%[1]s'",
				availableNodes[0],
			)
		} else {
			c.console.Info(
				"You can use 'ssh' to connect to nodes %s",
				logging.All(availableNodes),
			)
		}
	}

	// Prepare the data for the templates:
	type TemplateData struct {
		Cluster *models.Cluster
		Tmp     string
	}
	templateData := TemplateData{
		Cluster: c.cluster,
		Tmp:     tmpDir,
	}

	// Write the shell initialization file:
	bashrcPath := filepath.Join(tmpDir, ".bashrc")
	bashrcBuffer := &bytes.Buffer{}
	err = templateEngine.Execute(bashrcBuffer, "bashrc", templateData)
	if err != nil {
		return err
	}
	err = c.writeFile(bashrcPath, bashrcBuffer.Bytes(), 0400)
	if err != nil {
		return err
	}

	// Write the SSH keys:
	if c.cluster.SSH.PrivateKey != nil {
		sshPrivateKeyPath := filepath.Join(tmpDir, ".ssh", "id_rsa")
		err = c.writeFile(sshPrivateKeyPath, c.cluster.SSH.PrivateKey, 0400)
		if err != nil {
			return err
		}
	} else {
		c.console.Warn("SSH private key isn't available")
	}
	if c.cluster.SSH.PublicKey != nil {
		sshPublicKeyPath := filepath.Join(tmpDir, ".ssh", "id_rsa.pub")
		err = c.writeFile(sshPublicKeyPath, c.cluster.SSH.PublicKey, 0400)
		if err != nil {
			return err
		}
	} else {
		c.console.Warn("SSH public key isn't available")
	}

	// Write the SSH configuration file:
	sshConfigPath := filepath.Join(tmpDir, ".ssh", "config")
	sshConfigBuffer := &bytes.Buffer{}
	err = templateEngine.Execute(sshConfigBuffer, "ssh_config", templateData)
	if err != nil {
		return err
	}
	err = c.writeFile(sshConfigPath, sshConfigBuffer.Bytes(), 0400)
	if err != nil {
		return err
	}

	// Run the shell:
	shellArgs := []string{
		shellBinary,
		"--rcfile", bashrcPath,
		"-i",
	}
	shellCmd := &exec.Cmd{
		Path:   shellPath,
		Args:   shellArgs,
		Stdin:  c.tool.In(),
		Stdout: c.tool.Out(),
		Stderr: c.tool.Err(),
	}
	return shellCmd.Run()
}

func (c *ShellCommand) writeFile(name string, data []byte, perm fs.FileMode) error {
	dir := filepath.Dir(name)
	_, err := os.Stat(dir)
	if errors.Is(err, os.ErrNotExist) {
		err = os.MkdirAll(dir, 0700)
		if err != nil {
			return err
		}
	}
	return os.WriteFile(name, data, perm)
}

// Names of the command line flags:
const shellClusterFlagName = "cluster"

// Name of the shell command:
const shellBinary = "bash"
