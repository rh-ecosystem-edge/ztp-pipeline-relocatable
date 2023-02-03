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
	"fmt"
	"io"
	"runtime"
	"runtime/debug"
	"strings"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"golang.org/x/exp/maps"
	"golang.org/x/exp/slices"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

// ToolBuilder contains the data and logic needed to create an instance of the command line
// tool. Don't create instances of this directly, use the NewTool function instead.
type ToolBuilder struct {
	logger logr.Logger
	sub    []func() *cobra.Command
	envs   []any
	args   []string
	in     io.Reader
	out    io.Writer
	err    io.Writer
}

// Tool is an instance of the command line tool. Don't create instances of this directly, use the
// NewTool function instead.
type Tool struct {
	logger      logr.Logger
	loggerV     int
	loggerOwned bool
	cmd         *cobra.Command
	sub         []func() *cobra.Command
	env         map[string]string
	args        []string
	in          io.Reader
	out         io.Writer
	err         io.Writer
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
	b.sub = append(b.sub, value)
	return b
}

// AddCommands adds a list of sub-commands.
func (b *ToolBuilder) AddCommands(values ...func() *cobra.Command) *ToolBuilder {
	b.sub = append(b.sub, values...)
	return b
}

// SetEnv set the environment variables. The value can be a slice of strings or a map where both
// keys and values are strings. If it is a slice then each item should be a `NAME=value` pair.
func (b *ToolBuilder) SetEnv(value any) *ToolBuilder {
	b.envs = append(b.envs, value)
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
	for i, env := range b.envs {
		switch env.(type) {
		case []string, map[string]string:
		default:
			err = fmt.Errorf(
				"environment %d should be a list of strings or a map where both "+
					"keys and values are strings, but it is of type %T",
				i, env,
			)
			return
		}
	}

	// Create the environment variables:
	env, err := b.createEnv()
	if err != nil {
		return
	}

	// Create and populate the object:
	result = &Tool{
		logger: b.logger,
		sub:    slices.Clone(b.sub),
		env:    env,
		args:   slices.Clone(b.args),
		in:     b.in,
		out:    b.out,
		err:    b.err,
	}
	return
}

func (b *ToolBuilder) createEnv() (result map[string]string, err error) {
	result = map[string]string{}
	for _, data := range b.envs {
		switch typed := data.(type) {
		case []string:
			for _, item := range typed {
				equals := strings.Index(item, "=")
				var name, value string
				if equals != -1 {
					name = item[0:equals]
					value = item[equals+1:]
				} else {
					name = item
					value = ""
				}
				result[name] = value
			}
		case map[string]string:
			result = maps.Clone(typed)
		}
	}
	return
}

// Run rus the tool.
func (t *Tool) Run(ctx context.Context) error {
	// Create the main command:
	err := t.createCommand()
	if err != nil {
		return err
	}

	// Create a default logger that we can use while we haven't yet parsed the command line
	// flags that contain the logging configuration.
	if t.logger.GetSink() == nil {
		t.logger, err = t.createDefaultLogger()
		if err != nil {
			return err
		}
		t.loggerOwned = true
	}

	// Execute the main command:
	t.logger.V(1).Info(
		"Running command",
		"args", t.args,
	)
	t.cmd.SetArgs(t.args[1:])
	err = t.cmd.ExecuteContext(ctx)
	if err != nil {
		t.logger.Error(
			err,
			"Failed to run command",
			"args", t.args,
		)
	}
	return err
}

func (t *Tool) run(cmd *cobra.Command, args []string) error {
	var err error

	// Replace the default logger with one configured according to the command line options:
	if t.loggerOwned {
		t.logger, err = t.createConfiguredLogger()
		if err != nil {
			return err
		}
	}

	// Populate the context:
	ctx := cmd.Context()
	ctx = ToolIntoContext(ctx, t)
	ctx = LoggerIntoContext(ctx, t.logger)
	cmd.SetContext(ctx)

	// Write build information:
	t.writeBuildInfo()

	return nil
}

func (t *Tool) createCommand() error {
	// Create the main command:
	t.cmd = &cobra.Command{
		Use:               "ztp",
		Long:              "Zero touch provisioning command line tool",
		PersistentPreRunE: t.run,
		SilenceErrors:     true,
		SilenceUsage:      true,
	}

	// Add flags that apply to all the commands:
	flags := t.cmd.PersistentFlags()
	flags.IntVarP(
		&t.loggerV,
		"v",
		"v",
		0,
		"Log verbosity level.",
	)

	// Add sub-commands:
	for _, sub := range t.sub {
		t.cmd.AddCommand(sub())
	}

	return nil
}

func (t *Tool) createDefaultLogger() (result logr.Logger, err error) {
	result, err = logging.NewLogger().
		Build()
	return
}

func (t *Tool) createConfiguredLogger() (result logr.Logger, err error) {
	result, err = logging.NewLogger().
		SetV(t.loggerV).
		Build()
	return
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

// Env returns the environment variables of the tool. Note that this returns a copy of the variables
// used internally by the tool. If you are going to use only one variable it is cheaper to use the
// LookupEnv method.
func (t *Tool) Env() map[string]string {
	return maps.Clone(t.env)
}

// LookupEnv returns the environment variable of the tool with the given name and a boolean flag
// indicating if there is such environment variable.
func (t *Tool) LookupEnv(name string) (value string, ok bool) {
	value, ok = t.env[name]
	return
}
