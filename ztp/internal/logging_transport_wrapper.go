/*
Copyright (c) 2023 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing permissions and limitations under the
License.
*/

package internal

import (
	"errors"
	"fmt"
	"io"
	"net/http"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
)

// LoggingTransportWrapperBuilder contains the data and logic needed to build a transport wrapper
// that dumps to the log the details of HTTP requests and responses. Don't create instances of this
// type directly, use the NewLoggingTransportWrapper function instead.
type LoggingTransportWrapperBuilder struct {
	logger  logr.Logger
	headerV int
	bodyV   int
}

// LoggingTransportWrapper is a transport wrapper that creates round trippers that dump the details
// of the request and the responses to the log. Don't create instances of this type directly, ue the
// NewLoggingTransportWrapper function instead.
type LoggingTransportWrapper struct {
	headerLogger logr.Logger
	bodyLogger   logr.Logger
}

// loggingRoundTripper is an implementation of the http.RoundTripper interface that writes to the
// log the details of the requests and responses.
type loggingRoundTripper struct {
	headerLogger logr.Logger
	bodyLogger   logr.Logger
	wrapped      http.RoundTripper
}

type loggingRequestReader struct {
	logger logr.Logger
	id     string
	reader io.ReadCloser
}

type loggingResponseReader struct {
	logger logr.Logger
	id     string
	reader io.ReadCloser
}

// NewLoggingTransportWrapper creates a builder that can then be used to configure and create a
// logging transport wrapper.
func NewLoggingTransportWrapper() *LoggingTransportWrapperBuilder {
	return &LoggingTransportWrapperBuilder{
		headerV: 2,
		bodyV:   3,
	}
}

// SetLogger sets the logger that will be used to write request and response details to the log.
// This is mandatory.
func (b *LoggingTransportWrapperBuilder) SetLogger(
	value logr.Logger) *LoggingTransportWrapperBuilder {
	b.logger = value
	return b
}

// SetHeaderV sets the v-level that will be used to write the request and response header details.
// Default is 1.
func (b *LoggingTransportWrapperBuilder) SetHeaderV(value int) *LoggingTransportWrapperBuilder {
	b.headerV = value
	return b
}

// SetBodyV sets the v-level that will be used to write the request and response body details.
// Default is 2.
func (b *LoggingTransportWrapperBuilder) SetBodyV(value int) *LoggingTransportWrapperBuilder {
	b.bodyV = value
	return b
}

// Build uses the data stored in the builder to create and configure a new logging transport
// wrapper.
func (b *LoggingTransportWrapperBuilder) Build() (result *LoggingTransportWrapper, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.headerV < 0 {
		err = fmt.Errorf(
			"header v-level %d isn't valid, it must be greater than or equal to 0",
			b.headerV,
		)
		return
	}
	if b.bodyV < 0 {
		err = fmt.Errorf(
			"body v-level %d isn't valid, it must be greater than or equal to 0",
			b.bodyV,
		)
		return
	}

	// Create and populate the object:
	result = &LoggingTransportWrapper{
		headerLogger: b.logger.V(b.headerV),
		bodyLogger:   b.logger.V(b.bodyV),
	}

	return
}

// Wrap creates a round tripper on top of the given one that writes to the log the details of
// requests and responses.
func (w *LoggingTransportWrapper) Wrap(transport http.RoundTripper) http.RoundTripper {
	return &loggingRoundTripper{
		headerLogger: w.headerLogger,
		bodyLogger:   w.bodyLogger,
		wrapped:      transport,
	}
}

// Make sure that we implement the http.RoundTripper interface:
var _ http.RoundTripper = (*loggingRoundTripper)(nil)

// RoundTrip is he implementation of the http.RoundTripper interface.
func (t *loggingRoundTripper) RoundTrip(request *http.Request) (response *http.Response, err error) {
	// Generate an unique identifier for this request, so that it will be easier to correlate it
	// with the response:
	id := uuid.NewString()

	// Write the details of the request:
	t.dumpRequest(request, id)

	// Replace the request body with a reader that writes to the log:
	if t.bodyLogger.Enabled() && request.Body != nil {
		request.Body = &loggingRequestReader{
			logger: t.bodyLogger,
			id:     id,
			reader: request.Body,
		}
	}

	// Call the wrapped transport:
	response, err = t.wrapped.RoundTrip(request)
	if err != nil {
		return
	}

	// Replace the response body with a writer that writes to the log:
	if t.bodyLogger.Enabled() && response.Body != nil {
		response.Body = &loggingResponseReader{
			logger: t.bodyLogger,
			id:     id,
			reader: response.Body,
		}
	}

	// Write the details of the response:
	t.dumpResponse(response, id)

	return
}

func (t *loggingRoundTripper) dumpRequest(request *http.Request, id string) {
	t.headerLogger.Info(
		"Sending request header",
		"id", id,
		"method", request.Method,
		"url", request.URL,
		"host", request.Host,
		"headers", request.Header,
	)
}

func (t *loggingRoundTripper) dumpResponse(response *http.Response, id string) {
	t.headerLogger.Info(
		"Received response header",
		"id", id,
		"protocol", response.Proto,
		"status", response.Status,
		"code", response.StatusCode,
		"headers", response.Header,
	)
}

func (r *loggingRequestReader) Read(p []byte) (n int, err error) {
	n, err = r.reader.Read(p)
	if err != nil {
		return
	}
	r.logger.Info(
		"Sending request body",
		"id", r.id,
		"n", n,
	)
	return
}

func (r *loggingRequestReader) Close() error {
	return r.reader.Close()
}

func (r *loggingResponseReader) Read(p []byte) (n int, err error) {
	n, err = r.reader.Read(p)
	if err != nil {
		return
	}
	r.logger.Info(
		"Received response body",
		"id", r.id,
		"n", n,
	)
	return
}

func (r *loggingResponseReader) Close() error {
	return r.reader.Close()
}
