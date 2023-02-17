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
	"runtime/debug"

	"github.com/spf13/cobra"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
)

// Cobra creates and returns the `version` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	return &cobra.Command{
		Use:   "version",
		Short: "Prints the version information",
		Long:  "Prints the version information",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
}

// Command contains the data and logic needed to run the `version` command.
type Command struct {
}

// NewCommand creates a new runner that knows how to execute the `version` command.
func NewCommand() *Command {
	return &Command{}
}

// run executes the `version` command.
func (c *Command) run(cmd *cobra.Command, argv []string) error {
	// Get the context:
	ctx := cmd.Context()

	// Get the console:
	console := internal.ConsoleFromContext(ctx)

	// Calculate the values:
	buildCommit := unknownSettingValue
	buildTime := unknownSettingValue
	info, ok := debug.ReadBuildInfo()
	if ok {
		vcsRevision := c.getSetting(info, vcsRevisionSettingKey)
		if vcsRevision != "" {
			buildCommit = vcsRevision
		}
		vcsTime := c.getSetting(info, vcsTimeSettingKey)
		if vcsTime != "" {
			buildTime = vcsTime
		}
	}

	// Print the values:
	console.Info("Build commit: %s", buildCommit)
	console.Info("Build time: %s", buildTime)

	return nil
}

// getSetting returns the value of the build setting witht he given key. Returns an empty string
// if no such setting exists.
func (c *Command) getSetting(info *debug.BuildInfo, key string) string {
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
