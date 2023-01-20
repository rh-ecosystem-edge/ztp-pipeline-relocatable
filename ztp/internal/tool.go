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
	"os"
	"runtime"
	"runtime/debug"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

// ToolBuilder contains the data and logic needed to create an instance of the command line
// tool. Don't create instances of this directly, use the NewTool function instead.
type ToolBuilder struct {
	logger logr.Logger
	cmds   []func() *cobra.Command
	env    []string
	args   []string
	in     io.Reader
	out    io.Writer
	err    io.Writer
}

// Tool is an instance of the command line tool. Don't create instances of this directly, use the
// NewTool function instead.
type Tool struct {
	logger logr.Logger
	env    []string
	args   []string
	in     io.Reader
	out    io.Writer
	err    io.Writer
	main   *cobra.Command
}

// NewTool creates a builder that can then be used to configure and create an instance of the
// command line tool.
func NewTool() *ToolBuilder {
	return &ToolBuilder{}
}

// SetLogger sets the logger that the tool will use to write messages to the log. This is optional,
// and if not specified a new one will be created that writes JSON messages to a file `ztp.log` file
// inside the tool cache directory.
func (b *ToolBuilder) SetLogger(value logr.Logger) *ToolBuilder {
	b.logger = value
	return b
}

// AddCommand adds a sub-command.
func (b *ToolBuilder) AddCommand(value func() *cobra.Command) *ToolBuilder {
	b.cmds = append(b.cmds, value)
	return b
}

// AddCommands adds a list of sub-commands.
func (b *ToolBuilder) AddCommands(values ...func() *cobra.Command) *ToolBuilder {
	b.cmds = append(b.cmds, values...)
	return b
}

// AddEnv adds a collection of environment variables to the tool. Each value should be the name of
// the environment variable, followed by an equals sign and then the value.
func (b *ToolBuilder) AddEnv(values ...string) *ToolBuilder {
	b.env = append(b.env, values...)
	return b
}

// AddArg adds one command line argument.
func (b *ToolBuilder) AddArg(value string) *ToolBuilder {
	b.args = append(b.args, value)
	return b
}

// AddArgs adds a list of command line arguments.
func (b *ToolBuilder) AddArgs(values ...string) *ToolBuilder {
	b.args = append(b.args, values...)
	return b
}

// SetIn sets the standard input stream. This is mandatory.
func (b *ToolBuilder) SetIn(value io.Reader) *ToolBuilder {
	b.in = value
	return b
}

// SetOut sets the standard output stream. This is mandatory.
func (b *ToolBuilder) SetOut(value io.Writer) *ToolBuilder {
	b.out = value
	return b
}

// SetErr sets the standard error output stream. This is mandatory.
func (b *ToolBuilder) SetErr(value io.Writer) *ToolBuilder {
	b.err = value
	return b
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

	// Copy the environment variables:
	env := make([]string, len(b.env))
	copy(env, b.env)

	// Copy the command line arguments:
	args := make([]string, len(b.args))
	copy(args, b.args)

	// Create the command:
	main, err := b.createCommand()
	if err != nil {
		return
	}

	// Parse the command line, but without executing the command, as we want to create the
	// logger before that:
	err = main.ParseFlags(args[1:])
	if err != nil {
		return
	}

	// Create the logger:
	logger := b.logger
	if logger.GetSink() == nil {
		logger, err = b.createLogger(main.PersistentFlags())
		if err != nil {
			return
		}
	}
	// Create and populate the object:
	result = &Tool{
		logger: logger,
		env:    env,
		args:   args,
		in:     b.in,
		out:    b.out,
		err:    b.err,
		main:   main,
	}
	return
}

func (b *ToolBuilder) createLogger(flags *pflag.FlagSet) (result logr.Logger, err error) {
	// Get the values of the flags:
	var v int
	v, err = flags.GetInt("v")
	if err != nil {
		return
	}

	// Create the basic logger:
	result, err = NewLogger().SetV(v).Build()
	if err != nil {
		return
	}

	// Add the the PID so that it will be easy to identify the process when there are multiple
	// processes writing to the same log file:
	result = result.WithValues("pid", os.Getpid())
	return
}

func (b *ToolBuilder) createCommand() (result *cobra.Command, err error) {
	// Create the main command:
	result = &cobra.Command{
		Use:  "ztp",
		Long: "Zero touch provisioning command line tool",
	}

	// Add flags that apply to all the commands:
	flags := result.PersistentFlags()
	flags.IntP(
		"v",
		"v",
		0,
		"Log verbosity level.",
	)

	// Register sub-commands:
	for _, cmd := range b.cmds {
		result.AddCommand(cmd())
	}

	return
}

// Run rus the tool.
func (t *Tool) Run() error {
	// Create a context containing the tool and the logger:
	ctx := context.Background()
	ctx = ToolIntoContext(ctx, t)
	ctx = LoggerIntoContext(ctx, t.logger)

	// Write build information:
	t.writeBuildInfo()

	// Execute the main command:
	t.logger.V(1).Info(
		"Running command",
		"args", t.args,
	)
	t.main.SetArgs(t.args[1:])
	err := t.main.ExecuteContext(ctx)
	if err != nil {
		t.logger.Error(
			err,
			"Failed to run command",
			"args", t.args,
		)
	}
	return err
}

func (t *Tool) writeBuildInfo() {
	// Retrieve the information:
	buildInfo, ok := debug.ReadBuildInfo()
	if !ok {
		t.logger.Info("Build information isn't available")
		return
	}

	// Extract the information that we need:
	logFields := []any{
		"go", buildInfo.GoVersion,
		"os", runtime.GOOS,
		"arch", runtime.GOARCH,
	}
	for _, buildSetting := range buildInfo.Settings {
		switch buildSetting.Key {
		case "vcs.revision":
			logFields = append(logFields, "revision", buildSetting.Value)
		case "vcs.time":
			logFields = append(logFields, "time", buildSetting.Value)
		}
	}

	// Write the information:
	t.logger.Info("Build information", logFields...)
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
