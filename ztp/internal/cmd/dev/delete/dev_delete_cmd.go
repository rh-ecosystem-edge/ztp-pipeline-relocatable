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

package delete

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
)

// Cobra creates and returns the `dev delete` command.
func Cobra() *cobra.Command {
	// Create the command:
	c := NewCommand()
	result := &cobra.Command{
		Use:   "delete -f FILENAME",
		Short: "Deletes objects",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}

	// Add the flags:
	flags := result.Flags()
	flags.StringArrayVarP(
		&c.flags.files,
		"file",
		"f",
		[]string{"-"},
		"Name of the file containing the templates of the objects to be deleted. "+
			"Value '-' indicates that the file should be taken from the "+
			"standard input stream.",
	)

	return result
}

// Command contains the data and logic needed to run the `dev delete` command.
type Command struct {
	flags struct {
		files []string
	}
}

// NewCommand creates a new runner that knows how to execute the `dev delete` command.
func NewCommand() *Command {
	return &Command{}
}

// run executes the `dev delete` command.
func (c *Command) run(cmd *cobra.Command, argv []string) (err error) {
	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	logger := internal.LoggerFromContext(ctx)
	tool := internal.ToolFromContext(ctx)

	// Create a temporary directory where we can copy all the input files to pass them to the
	// applier:
	tmp, err := os.MkdirTemp("", "*.ztp")
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create temporary directory: %v\n",
			err,
		)
	}
	defer os.RemoveAll(tmp)
	for i, file := range c.flags.files {
		var (
			name string
			data []byte
		)
		if file == "-" {
			name = fmt.Sprintf("%d.yaml", i)
			data, err = io.ReadAll(tool.In())
			if err != nil {
				fmt.Fprintf(
					tool.Err(),
					"Failed to read standard input stream: %v\n",
					err,
				)
				return exit.Error(1)
			}
		} else {
			base := filepath.Base(file)
			name = fmt.Sprintf("%d-%s", i, base)
			data, err = os.ReadFile(file)
			if err != nil {
				fmt.Fprintf(
					tool.Err(),
					"Failed to read file '%s': %v\n",
					file, err,
				)
				return exit.Error(1)
			}
		}
		path := filepath.Join(tmp, name)
		err = os.WriteFile(path, data, 0400)
		if err != nil {
			fmt.Fprintf(
				tool.Err(),
				"Failed to copy file '%s' to temporary directory: %v\n",
				file, err,
			)
			return exit.Error(1)
		}
	}

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
		SetFS(os.DirFS(tmp)).
		Build()
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to create applier: %v\n",
			err,
		)
		return exit.Error(1)
	}
	err = applier.Delete(ctx, nil)
	if err != nil {
		fmt.Fprintf(
			tool.Err(),
			"Failed to delete objects: %v\n",
			err,
		)
		return exit.Error(1)
	}

	return nil
}
