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

package internal

import (
	"errors"
	"fmt"
	"io"
	"os"
	"sync"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	"golang.org/x/term"
)

// ConsoleBuilder contains the data and logic needed to create an instance of the console. Don't
// create instances of this directly, use the NewConsole function instead.
type ConsoleBuilder struct {
	logger logr.Logger
	color  bool
	out    io.Writer
	err    io.Writer
}

// Console knows how to write messages to the terminal. Don't create instances of this directly, use
// the NewConsole function instead.
type Console struct {
	logger   logr.Logger
	lock     *sync.Mutex
	prefixes consolePrefixes
	out      io.Writer
	err      io.Writer
}

// NewConsole creates a builder that can then be used to configure and create a console.
func NewConsole() *ConsoleBuilder {
	return &ConsoleBuilder{
		color: true,
	}
}

// SetLogger sets the logger that the console will use to write messages to the log. This is
// mandatory.
func (b *ConsoleBuilder) SetLogger(value logr.Logger) *ConsoleBuilder {
	b.logger = value
	return b
}

// SetOut sets the standard output stream. This is mandatory.
func (b *ConsoleBuilder) SetOut(value io.Writer) *ConsoleBuilder {
	b.out = value
	return b
}

// SetErr sets the standard error stream. This is mandatory.
func (b *ConsoleBuilder) SetErr(value io.Writer) *ConsoleBuilder {
	b.err = value
	return b
}

// SetFlags sets the command line flags that that indicate how to configure the console. This is
// optional.
func (b *ConsoleBuilder) SetFlags(flags *pflag.FlagSet) *ConsoleBuilder {
	if flags.Changed(consoleColorFlag) {
		value, err := flags.GetBool(consoleColorFlag)
		if err == nil {
			b.color = value
		}
	}
	return b
}

// Build uses the data stored in the buider to create a new instance of the console.
func (b *ConsoleBuilder) Build() (result *Console, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.out == nil {
		err = errors.New("standard output stream is mandatory")
		return
	}
	if b.err == nil {
		err = errors.New("standard error stream is mandatory")
		return
	}

	// Check if the ouptput is a terminal:
	terminal := b.isTerminal(b.out) && b.isTerminal(b.err)

	// Select the color prefixes:
	prefixes := consoleMonoPrefixes
	if b.color && terminal {
		prefixes = consoleColorPrefixes
	}

	// Create and populate the object:
	result = &Console{
		logger:   b.logger,
		lock:     &sync.Mutex{},
		prefixes: prefixes,
		out:      b.out,
		err:      b.err,
	}
	return
}

func (c *ConsoleBuilder) isTerminal(w io.Writer) bool {
	file, ok := w.(*os.File)
	if !ok {
		return false
	}
	return term.IsTerminal(int(file.Fd()))
}

// Info writes an informative message to the console.
func (c *Console) Info(format string, args ...any) {
	c.lock.Lock()
	defer c.lock.Unlock()
	text := fmt.Sprintf(format, args...)
	fmt.Fprintf(c.out, "%s%s\n", c.prefixes.info, text)
	c.logger.Info("Console info", "text", text)
}

// Wanr writes an warning message to the console.
func (c *Console) Warn(format string, args ...any) {
	c.lock.Lock()
	defer c.lock.Unlock()
	text := fmt.Sprintf(format, args...)
	fmt.Fprintf(c.out, "%s%s\n", c.prefixes.warn, text)
	c.logger.Info("Console warn", "text", text)
}

// Info writes an error message to the console.
func (c *Console) Error(format string, args ...any) {
	c.lock.Lock()
	defer c.lock.Unlock()
	text := fmt.Sprintf(format, args...)
	fmt.Fprintf(c.err, "%s%s\n", c.prefixes.error, text)
	c.logger.Info("Console error", "text", text)
}

// consolePrefixes stores the prefixes used for messages.
type consolePrefixes struct {
	info  string
	warn  string
	error string
}

// consoleColorPrefixes contains the prefixes that use ANSI sequences to set colors when the output
// is a terminal that supports color.
var consoleColorPrefixes = consolePrefixes{
	info:  "\033[32;1mI:\033[0m ",
	warn:  "\033[33;1mW:\033[0m ",
	error: "\033[31;1mE:\033[0m ",
}

// consoleMonoPrefixes contains the monochrome prefixes that are used when the output isn't a
// terminal or when the terminal doesn't support color.
var consoleMonoPrefixes = consolePrefixes{
	info:  "I: ",
	warn:  "W: ",
	error: "E: ",
}
