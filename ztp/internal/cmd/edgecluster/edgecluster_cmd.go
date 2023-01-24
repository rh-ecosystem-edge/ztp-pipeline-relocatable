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

package edgecluster

import (
	"fmt"
	"os"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/spf13/cobra"
)

// Command creates and returns the `edgecluster` command.
func Command() *cobra.Command {
	return &cobra.Command{
		Use:   "edgecluster TIMEOUT",
		Short: "Creates an edge cluster",
		Long:  "Creates an edge cluster",
		Args:  cobra.ExactArgs(1),
		RunE:  run,
	}
}

// run executes the `edgecluster` command.
func run(cmd *cobra.Command, argv []string) error {
	// Get the context:
	ctx := cmd.Context()

	// Get the tool:
	tool := internal.ToolFromContext(ctx)
	logger := internal.LoggerFromContext(ctx)

	// Load the configuration:
	configFile, ok := os.LookupEnv("EDGECLUSTERS_FILE")
	if !ok {
		return fmt.Errorf(
			"failed to load configuration because environment variable " +
				"'EDGECLUSTERS_FILE' isn't defined",
		)
	}
	config, err := internal.NewConfigLoader().
		SetLogger(logger).
		SetSource(configFile).
		Load()
	if err != nil {
		return fmt.Errorf(
			"failed to load configuration from file '%s': %v",
			configFile, err,
		)
	}

	// TODO: This is an example of how to use the configuration, it will eventually be removed.
	fmt.Fprintf(tool.Out(), "Properties:\n")
	for name, value := range config.Properties {
		fmt.Fprintf(tool.Out(), "\t%s: %s\n", name, value)
	}
	for _, cluster := range config.Clusters {
		fmt.Fprintf(tool.Out(), "Cluster '%s':\n", cluster.Name)
		for _, node := range cluster.Nodes {
			fmt.Fprintf(tool.Out(), "\tNode '%s'\n", node.Name)
			fmt.Fprintf(tool.Out(), "\t\tKind: %s\n", node.Kind)
			fmt.Fprintf(tool.Out(), "\t\tBMC URL: %s\n", node.BMC.URL)
			fmt.Fprintf(tool.Out(), "\t\tBMC user: %s\n", node.BMC.User)
			fmt.Fprintf(tool.Out(), "\t\tBMC password: %s\n", node.BMC.Pass)
			fmt.Fprintf(tool.Out(), "\t\tRoot disk: %s\n", node.RootDisk)
			if len(node.StorageDisks) > 0 {
				fmt.Fprintf(tool.Out(), "\t\tStorage disks:\n")
				for _, disk := range node.StorageDisks {
					fmt.Fprintf(tool.Out(), "\t\t\t%s\n", disk)
				}
			}
			fmt.Fprintf(tool.Out(), "\t\tInternal NIC:\n")
			fmt.Fprintf(tool.Out(), "\t\t\tName: %s\n", node.InternalNIC.Name)
			fmt.Fprintf(tool.Out(), "\t\t\tMAC: %s\n", node.InternalNIC.MAC)
			fmt.Fprintf(tool.Out(), "\t\tExternal NIC:\n")
			fmt.Fprintf(tool.Out(), "\t\t\tName: %s\n", node.ExternalNIC.Name)
			fmt.Fprintf(tool.Out(), "\t\t\tMAC: %s\n", node.ExternalNIC.MAC)
		}
	}

	return nil
}
