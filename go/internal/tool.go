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

package internal

import (
	"context"
	"errors"
	"io"

	"github.com/spf13/cobra"
)

// ToolBuilder contains the data and logic needed to create an instance of the command line
// tool. Don't create instances of this directly, use the NewTool function instead.
type ToolBuilder struct {
	cmds []func() *cobra.Command
	args []string
	in   io.Reader
	out  io.Writer
	err  io.Writer
}

// Tool is an instance of the command line tool. Don't create instances of this directly, use the
// NewTool function instead.
type Tool struct {
	cmds []func() *cobra.Command
	args []string
	in   io.Reader
	out  io.Writer
	err  io.Writer
}

// Command adds a sub-command.
func (b *ToolBuilder) Command(value func() *cobra.Command) *ToolBuilder {
	b.cmds = append(b.cmds, value)
	return b
}

// Commands adds a list of sub-commands.
func (b *ToolBuilder) Commands(values ...func() *cobra.Command) *ToolBuilder {
	b.cmds = append(b.cmds, values...)
	return b
}

// Arg adds one command line argument.
func (b *ToolBuilder) Arg(value string) *ToolBuilder {
	b.args = append(b.args, value)
	return b
}

// Args adds a list of command line arguments.
func (b *ToolBuilder) Args(values ...string) *ToolBuilder {
	b.args = append(b.args, values...)
	return b
}

// In sets the standard input stream. This is mandatory.
func (b *ToolBuilder) In(value io.Reader) *ToolBuilder {
	b.in = value
	return b
}

// Out sets the standard output stream. This is mandatory.
func (b *ToolBuilder) Out(value io.Writer) *ToolBuilder {
	b.out = value
	return b
}

// Err sets the standard error output stream. This is mandatory.
func (b *ToolBuilder) Err(value io.Writer) *ToolBuilder {
	b.err = value
	return b
}

// NewTool creates a builder that can then be used to configure and create an instance of the
// command line tool.
func NewTool() *ToolBuilder {
	return &ToolBuilder{}
}

// Build uses the data stored in the buider to create a new instance of the command line tool.
func (b *ToolBuilder) Build() (result *Tool, err error) {
	// Check parameters:
	if len(b.args) == 0 {
		err = errors.New(
			"at least one command line argument (usually the name of the binary) is " +
				"required",
		)
		return
	}
	if b.in == nil {
		err = errors.New("standard input stream is mandatory")
		return
	}
	if b.out == nil {
		err = errors.New("standard output stream is mandatory")
		return
	}
	if b.err == nil {
		err = errors.New("standard error output stream is mandatory")
		return
	}

	// Copy the command line arguments:
	args := make([]string, len(b.args))
	copy(args, b.args)

	// Copy the commands:
	cmds := make([]func() *cobra.Command, len(b.cmds))
	copy(cmds, b.cmds)

	// Create and populate the object:
	result = &Tool{
		args: args,
		in:   b.in,
		out:  b.out,
		err:  b.err,
		cmds: cmds,
	}
	return
}

// Run rus the tool.
func (t *Tool) Run() error {
	// Create the main command:
	main := &cobra.Command{
		Use:  "ztp",
		Long: "Zero touch provisioning command line tool",
	}

	// Register sub-commands:
	for _, cmd := range t.cmds {
		main.AddCommand(cmd())
	}

	// Create a context containing the tool, so that commands can extract and use it:
	ctx := ToolIntoContext(context.Background(), t)

	// Execute the main command:
	main.SetArgs(t.args[1:])
	return main.ExecuteContext(ctx)
}

// In returns the input stream of the tool.
func (t *Tool) In() io.Reader {
	return t.in
}

// Out returns the output stream of the tool.
func (t *Tool) Out() io.Writer {
	return t.out
}

// Err returns the error output stream of the tool.
func (t *Tool) Err() io.Writer {
	return t.err
}
