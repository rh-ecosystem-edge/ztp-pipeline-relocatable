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

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/spf13/cobra"
)

// Command creates and returns the `edgecluster` command.
func Command() *cobra.Command {
	return &cobra.Command{
		Use:   "edgecluster",
		Short: "Creates an edge cluster",
		Long:  "Creates an edge cluster",
		Args:  cobra.NoArgs,
		RunE:  run,
	}
}

// run executes the `edgecluster` command.
func run(cmd *cobra.Command, argv []string) error {
	// Get the tool:
	tool := internal.ToolFromContext(cmd.Context())

	// Print the server version:
	kclient, err := internal.GetClient()
	if err != nil {
		return err
	}
	sv, err := kclient.Discovery().ServerVersion()
	if err != nil {
		return err
	}
	out := tool.Out()
	fmt.Fprintf(out, "Server version: %s\n", sv.String())

	return nil
}
