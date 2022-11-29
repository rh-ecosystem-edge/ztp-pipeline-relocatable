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

package version

import (
	"fmt"
	"runtime/debug"

	"github.com/spf13/cobra"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/go/internal"
)

// Command creates and returns the version command.
func Command() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Prints the version information",
		Long:  "Prints the version information",
		Args:  cobra.NoArgs,
		RunE:  run,
	}
}

// run executes the version command.
func run(cmd *cobra.Command, argv []string) error {
	// Get the tool:
	tool := internal.ToolFromContext(cmd.Context())

	// Calculate the values:
	buildCommit := unknownSettingValue
	buildTime := unknownSettingValue
	info, ok := debug.ReadBuildInfo()
	if ok {
		vcsRevision := getSetting(info, vcsRevisionSettingKey)
		if vcsRevision != "" {
			buildCommit = vcsRevision
		}
		vcsTime := getSetting(info, vcsTimeSettingKey)
		if vcsTime != "" {
			buildTime = vcsTime
		}
	}

	// Print the values:
	out := tool.Out()
	fmt.Fprintf(out, "Build commit: %s\n", buildCommit)
	fmt.Fprintf(out, "Build time: %s\n", buildTime)

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
