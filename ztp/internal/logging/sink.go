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

package logging

import (
	"strings"

	"github.com/go-logr/logr"
)

// sink is an implementation of the logr.LogSink interface that processes the fields of log messages
// before sending them to the underlying logger. For example, it redacts the values of security
// sensitive fields.
type sink struct {
	settings *sinkSettings
	delegate logr.LogSink
}

// sinkSettings stores settings shared by multiple sinks.
type sinkSettings struct {
	redact bool
}

// Make sure we implement the logr.LogSink interface.
var _ logr.LogSink = (*sink)(nil)

func (s *sink) Enabled(level int) bool {
	return s.delegate.Enabled(level)
}

func (s *sink) Error(err error, msg string, fields ...any) {
	s.processFields(fields)
	s.delegate.Error(err, msg, fields...)
}

func (s *sink) Info(level int, msg string, fields ...any) {
	s.processFields(fields)
	s.delegate.Info(level, msg, fields...)
}

func (s *sink) Init(info logr.RuntimeInfo) {
	s.delegate.Init(info)
}

func (s *sink) WithName(name string) logr.LogSink {
	return &sink{
		settings: s.settings,
		delegate: s.delegate.WithName(name),
	}
}

func (s *sink) WithValues(fields ...any) logr.LogSink {
	s.processFields(fields)
	return &sink{
		settings: s.settings,
		delegate: s.delegate.WithValues(fields...),
	}
}

func (s *sink) processFields(args []any) {
	for i := 0; i < len(args); i += 2 {
		name, ok := args[i].(string)
		if ok {
			if strings.HasPrefix(name, "!") {
				args[i] = name[1:]
				if s.settings.redact {
					args[i+1] = "***"
				}
			}
		}
	}
}
