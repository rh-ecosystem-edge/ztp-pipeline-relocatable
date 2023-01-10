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

	"github.com/go-logr/logr"
)

// contextKey is the type used to store the tool in the context.
type contextKey int

const (
	contextToolKey contextKey = iota
	contextLoggerKey
)

// ToolFromContext returns the tool from the context. It panics if the given context doesn't contain
// the tool.
func ToolFromContext(ctx context.Context) *Tool {
	tool := ctx.Value(contextToolKey).(*Tool)
	if tool == nil {
		panic("failed to get tool from context")
	}
	return tool
}

// ToolIntoContext creates a new context that contains the given tool.
func ToolIntoContext(ctx context.Context, tool *Tool) context.Context {
	return context.WithValue(ctx, contextToolKey, tool)
}

// LoggerFromContext returns the logger from the context. It panics if the given context doesn't
// contain a logger.
func LoggerFromContext(ctx context.Context) logr.Logger {
	logger := ctx.Value(contextLoggerKey).(logr.Logger)
	if logger.GetSink() == nil {
		panic("failed to get logger from context")
	}
	return logger
}

// LoggerIntoContext creates a new context that contains the given logger.
func LoggerIntoContext(ctx context.Context, logger logr.Logger) context.Context {
	return context.WithValue(ctx, contextLoggerKey, logger)
}
