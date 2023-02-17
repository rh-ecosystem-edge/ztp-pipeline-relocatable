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

package setup

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/labels"
)

// Cobra creates and returns the `dev setup` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	result := &cobra.Command{
		Use:   "setup",
		Short: "Prepares the development environment",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
	return result
}

// Command contains the data and logic needed to run the `dev setup` command.
type Command struct {
}

// NewCommand creates a new runner that knows how to execute the `dev setup` command.
func NewCommand() *Command {
	return &Command{}
}

// run executes the `dev setup` command.
func (c *Command) run(cmd *cobra.Command, argv []string) (err error) {
	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	logger := internal.LoggerFromContext(ctx)
	tool := internal.ToolFromContext(ctx)

	// Create the client for the API:
	client, err := internal.NewClient().
		SetLogger(logger).
		Build()
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create client: %v\n",
			err,
		)
		return exit.Error(1)
	}
	defer client.Close()

	// Create the objects:
	listener, err := internal.NewApplierListener().
		SetLogger(logger).
		SetOut(tool.Out()).
		SetErr(tool.Err()).
		Build()
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create listener: %v\n",
			err,
		)
		return exit.Error(1)
	}
	applier, err := internal.NewApplier().
		SetLogger(logger).
		SetClient(client).
		SetListener(listener.Func).
		SetFS(internal.DataFS).
		SetRoot("data/dev").
		SetDirs("crds", "objects").
		AddLabel(labels.ZTPFW, "").
		Build()
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create applier: %v\n",
			err,
		)
		return exit.Error(1)
	}
	err = applier.Create(ctx, nil)
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create objects: %v\n",
			err,
		)
		return exit.Error(1)
	}

	return nil
}
