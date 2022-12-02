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
	"runtime/debug"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/spf13/cobra"
)

// Command creates and returns the version command.
func Command() *cobra.Command {
	return &cobra.Command{
		Use:   "edgecluster",
		Short: "Prints the version information",
		Long:  "Prints the version information",
		Args:  cobra.NoArgs,
		RunE:  run,
	}
}

// run executes the version command.
func run(cmd *cobra.Command, argv []string) error {
	kclient, err := internal.GetClient()
	if err != nil {
		return err
	}

	sv, err := kclient.Discovery().ServerVersion()
	if err != nil {
		return err
	}

	// Get the tool:
	tool := internal.ToolFromContext(cmd.Context())

	out := tool.Out()
	fmt.Fprintf(out, "Server version: %s\n", sv.String())

	return nil
}

// getSetting returns the value of the build setting witht he given key. Returns an empty string
// if no such setting exists.
func getSetting(info *debug.BuildInfo, key string) string {
	for _, s := range info.Settings {
		if s.Key == key {
			return s.Value
		}
	}
	return ""
}

// Names of build settings we are interested on:
const (
	vcsRevisionSettingKey = "vcs.revision"
	vcsTimeSettingKey     = "vcs.time"
)

// Fallback value for unknown settings:
const unknownSettingValue = "unknown"
