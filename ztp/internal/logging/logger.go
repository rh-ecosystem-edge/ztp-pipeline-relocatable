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
	"time"

	"github.com/go-logr/logr"
	"github.com/go-logr/zapr"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// LoggerBuilder contains the data and logic needed to create a logger. Don't create instances of
// this directly, use the NewLogger function instead.
type LoggerBuilder struct {
	writer io.Writer
	v      int
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

// SetV sets the maximum v-level, so that messages with a v-level higher than this won't be written
// to the log. The minimum and default value is zero. Errors are always writen too the log,
// regardless of this setting.
func (b *LoggerBuilder) SetV(value int) *LoggerBuilder {
	b.v = value
	return b
}

// Build uses the data stored in the buider to create a new logger.
func (b *LoggerBuilder) Build() (result logr.Logger, err error) {
	// Check parameters:
	if b.v < 0 {
		err = fmt.Errorf(
			"v-level %d isn't valid, it must be greater than or equal to zero",
			b.v,
		)
		return
	}

	// If no writer has been specified then open the default log file:
	writer := b.writer
	if writer == nil {
		writer, err = b.openDefaultFile()
		if err != nil {
			return
		}
	}

	// Map the v-level to a zap level, taking into account that in zap there is a maximum of 128
	// custom level and they are negative.
	var level zapcore.Level
	if b.v <= 128 {
		level = zapcore.Level(-b.v)
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

	// Create the logr logger:
	result = zapr.NewLoggerWithOptions(logger, zapr.LogInfoLevel("v"))

	// Add the the PID so that it will be easy to identify the process when there are multiple
	// processes writing to the same log file:
	result = result.WithValues("pid", os.Getpid())

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
	result, err = os.OpenFile(file, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0770)
	return
}

// loggerTimeEncoder converts the time to UTC and uses the RFC3339 format.
func loggerTimeEncoder(t time.Time, enc zapcore.PrimitiveArrayEncoder) {
	zapcore.RFC3339TimeEncoder(t.UTC(), enc)
}

// loggerLevelEncoder encodes the log level avoding negative numbers. For example, if the original
// v-level is 42 then the zapr adapter that we use will translate it into -42, because zap expects
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
