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

package logging

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/go-logr/logr"
	"github.com/go-logr/zapr"
	"github.com/spf13/pflag"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"golang.org/x/exp/maps"
)

// LoggerBuilder contains the data and logic needed to create a logger. Don't create instances of
// this directly, use the NewLogger function instead.
type LoggerBuilder struct {
	writer io.Writer
	out    io.Writer
	err    io.Writer
	level  int
	file   string
	fields map[string]any
}

// NewLogger creates a builder that can then be used to configure and create a logger.
func NewLogger() *LoggerBuilder {
	return &LoggerBuilder{}
}

// SetWriter sets the writer that the logger will write to. This is optional, and if not specified
// the the logger will write to a `ztp.log` file inside the `ztp` subdirectory of the user cache
// directory. For example, in a Linux system the default file will be `~/.cache/ztp/ztp.log`
func (b *LoggerBuilder) SetWriter(value io.Writer) *LoggerBuilder {
	b.writer = value
	return b
}

// SetOut sets the standard output stream. This is optional and will only be used then the log file
// is 'stdout'.
func (b *LoggerBuilder) SetOut(value io.Writer) *LoggerBuilder {
	b.out = value
	return b
}

// SetErr sets the standard error output stream. This is optional and will only be used when the log
// file is 'stderr'.
func (b *LoggerBuilder) SetErr(value io.Writer) *LoggerBuilder {
	b.err = value
	return b
}

// AddField adds a field that will be added to all the log messages. The following field values have
// special meanings:
//
// - %p: Is replaced by the process identifier.
//
// Any other field value is added without change.
func (b *LoggerBuilder) AddField(name string, value any) *LoggerBuilder {
	if b.fields == nil {
		b.fields = map[string]any{}
	}
	b.fields[name] = value
	return b
}

// AddFields adds a set of fields that will be added to all the log messages. See the AddField
// method for the meanings of values.
func (b *LoggerBuilder) AddFields(values map[string]any) *LoggerBuilder {
	if b.fields == nil {
		b.fields = maps.Clone(values)
	} else {
		maps.Copy(b.fields, values)
	}
	return b
}

// SetFields sets the fields tht will be added to all the log messages. See the AddField method for
// the meanings of values. Note that this replaces any previously configured fields. If you want to
// preserve them use the AddFields method.
func (b *LoggerBuilder) SetFields(values map[string]any) *LoggerBuilder {
	b.fields = maps.Clone(values)
	return b
}

// SetLevel sets the maximum log level, so that messages with a level higher than this won't be
// written to the log. The minimum and default value is zero. Errors are always writen too the log,
// regardless of this setting.
func (b *LoggerBuilder) SetLevel(value int) *LoggerBuilder {
	b.level = value
	return b
}

// SetFile sets the file that the logger will write to. This is optional, and if not specified
// the the logger will write to a `ztp.log` file inside the `ztp` subdirectory of the user cache
// directory. For example, in a Linux system the default file will be `~/.cache/ztp/ztp.log`
func (b *LoggerBuilder) SetFile(value string) *LoggerBuilder {
	b.file = value
	return b
}

// SetFlags sets the command line flags that should be used to configure the logger. This is
// optional.
func (b *LoggerBuilder) SetFlags(flags *pflag.FlagSet) *LoggerBuilder {
	if flags.Changed(levelFlagName) {
		value, err := flags.GetInt(levelFlagName)
		if err == nil {
			b.SetLevel(value)
		}
	}
	if flags.Changed(fileFlagName) {
		value, err := flags.GetString(fileFlagName)
		if err == nil {
			b.SetFile(value)
		}
	}
	if flags.Changed(fieldFlagName) {
		values, err := flags.GetStringArray(fieldFlagName)
		if err == nil {
			fields := b.parseFieldItems(values)
			b.AddFields(fields)
		}
	}
	if flags.Changed(fieldsFlagName) {
		values, err := flags.GetStringSlice(fieldsFlagName)
		if err == nil {
			fields := b.parseFieldItems(values)
			b.AddFields(fields)
		}
	}
	return b
}

func (b *LoggerBuilder) parseFieldItems(items []string) map[string]any {
	fields := map[string]any{}
	for _, item := range items {
		name, value := b.parseFieldItem(item)
		fields[name] = value
	}
	return fields
}

func (b *LoggerBuilder) parseFieldItem(item string) (name string, value any) {
	switch item {
	case pidLogFieldValue:
		name = pidLogFieldName
		value = pidLogFieldValue
	default:
		equals := strings.Index(item, "=")
		if equals != -1 {
			name = item[0:equals]
			value = item[equals+1:]
		} else {
			name = item
			value = ""
		}
		name = strings.TrimSpace(name)
	}
	return
}

// Build uses the data stored in the buider to create a new logger.
func (b *LoggerBuilder) Build() (result logr.Logger, err error) {
	// Check parameters:
	if b.level < 0 {
		err = fmt.Errorf(
			"level %d isn't valid, it must be greater than or equal to zero",
			b.level,
		)
		return
	}

	// If no writer has been explicitly provided then open the log file:
	writer := b.writer
	if writer == nil {
		writer, err = b.openWriter()
		if err != nil {
			return
		}
	}

	// Map the level to a zap level, taking into account that in zap there is a maximum of 128
	// custom level and they are negative.
	var level zapcore.Level
	if b.level <= 128 {
		level = zapcore.Level(-b.level)
	} else {
		level = zapcore.Level(-128)
	}

	// Create the zap logger:
	sink := zapcore.AddSync(writer)
	config := zap.NewProductionEncoderConfig()
	config.EncodeTime = loggerTimeEncoder
	config.EncodeLevel = loggerLevelEncoder
	encoder := zapcore.NewJSONEncoder(config)
	core := zapcore.NewCore(encoder, sink, level)
	logger := zap.New(core)

	// Caculate the custom fields:
	fields, err := b.customFields()
	if err != nil {
		return
	}

	// Create the logr logger:
	result = zapr.NewLoggerWithOptions(logger, zapr.LogInfoLevel("v"))
	if len(fields) > 0 {
		result = result.WithValues(fields...)
	}

	return
}

func (b *LoggerBuilder) openWriter() (result io.Writer, err error) {
	switch b.file {
	case "stdout":
		if b.out != nil {
			result = b.out
		} else {
			result = os.Stdout
		}
	case "stderr":
		if b.err != nil {
			result = b.err
		} else {
			result = os.Stderr
		}
	case "":
		result, err = b.openDefaultFile()
	default:
		result, err = b.openFile(b.file)
	}
	return
}

func (b *LoggerBuilder) openDefaultFile() (result io.Writer, err error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return
	}
	dir = filepath.Join(dir, "ztp")
	_, err = os.Stat(dir)
	if errors.Is(err, os.ErrNotExist) {
		err = os.MkdirAll(dir, 0700)
		if err != nil {
			return
		}
	}
	file := filepath.Join(dir, "ztp.log")
	result, err = b.openFile(file)
	return
}

func (b *LoggerBuilder) openFile(file string) (result io.Writer, err error) {
	result, err = os.OpenFile(file, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0660)
	return
}

func (b *LoggerBuilder) customFields() (result []any, err error) {
	names := maps.Keys(b.fields)
	sort.Strings(names)
	fields := make([]any, 2*len(names))
	for i, name := range names {
		value := b.fields[name]
		fields[2*i] = name
		fields[2*i+1], err = b.customField(name, value)
		if err != nil {
			return
		}
	}
	result = fields
	return
}

func (b *LoggerBuilder) customField(name string, value any) (result any, err error) {
	switch value {
	case pidLogFieldValue:
		result = os.Getpid()
	default:
		result = value
	}
	return
}

// loggerTimeEncoder converts the time to UTC and uses the RFC3339 format.
func loggerTimeEncoder(t time.Time, enc zapcore.PrimitiveArrayEncoder) {
	zapcore.RFC3339TimeEncoder(t.UTC(), enc)
}

// loggerLevelEncoder encodes the log level avoding negative numbers. For example, if the original
// level is 42 then the zapr adapter that we use will translate it into -42, because zap expects
// negative number for custom log levels. As a result the generated message would be something like
// this:
//
//	{"level": "Level(-42)", ...}
//
// But we want it to be the `debug`:
//
//	{"level": "debug", ...}
func loggerLevelEncoder(l zapcore.Level, enc zapcore.PrimitiveArrayEncoder) {
	switch l {
	case zap.ErrorLevel, zap.WarnLevel, zap.InfoLevel, zap.DebugLevel:
		enc.AppendString(l.String())
	default:
		enc.AppendString(zap.DebugLevel.String())
	}
}

// Values of log fields with special meanings. For example '%p' will be replaced with the identifier
// of the process.
const (
	pidLogFieldName  = "pid"
	pidLogFieldValue = "%p"
)
