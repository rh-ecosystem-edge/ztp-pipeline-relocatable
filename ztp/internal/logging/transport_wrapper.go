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

package logging

import (
	"errors"
	"fmt"
	"io"
	"net/http"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	"github.com/spf13/pflag"
)

// TransportWrapperBuilder contains the data and logic needed to build a transport wrapper that
// dumps to the log the details of HTTP requests and responses. Don't create instances of this type
// directly, use the NewLoggingTransportWrapper function instead.
type TransportWrapperBuilder struct {
	logger      logr.Logger
	headerLevel int
	bodyLevel   int
}

// TransportWrapper is a transport wrapper that creates round trippers that dump the details of the
// request and the responses to the log. Don't create instances of this type directly, ue the
// NewLoggingTransportWrapper function instead.
type TransportWrapper struct {
	headerLogger logr.Logger
	bodyLogger   logr.Logger
}

// roundTripper is an implementation of the http.RoundTripper interface that writes to the log the
// details of the requests and responses.
type roundTripper struct {
	headerLogger logr.Logger
	bodyLogger   logr.Logger
	wrapped      http.RoundTripper
}

type requestReader struct {
	logger logr.Logger
	id     string
	reader io.ReadCloser
}

type responseReader struct {
	logger logr.Logger
	id     string
	reader io.ReadCloser
}

// NewTransportWrapper creates a builder that can then be used to configure and create a logging
// transport wrapper.
func NewTransportWrapper() *TransportWrapperBuilder {
	return &TransportWrapperBuilder{
		headerLevel: 2,
		bodyLevel:   3,
	}
}

// SetLogger sets the logger that will be used to write request and response details to the log.
// This is mandatory.
func (b *TransportWrapperBuilder) SetLogger(
	value logr.Logger) *TransportWrapperBuilder {
	b.logger = value
	return b
}

// SetHeaderLevel sets the level that will be used to write the request and response header details.
// Default is one.
func (b *TransportWrapperBuilder) SetHeaderLevel(value int) *TransportWrapperBuilder {
	b.headerLevel = value
	return b
}

// SetBodyLevel sets the level that will be used to write the request and response body details.
// Default is two.
func (b *TransportWrapperBuilder) SetBodyLevel(value int) *TransportWrapperBuilder {
	b.bodyLevel = value
	return b
}

// SetFlags sets the command line flags that should be used to configure the logger. This is
// optional.
func (b *TransportWrapperBuilder) SetFlags(flags *pflag.FlagSet) *TransportWrapperBuilder {
	return b
}

// Build uses the data stored in the builder to create and configure a new logging transport
// wrapper.
func (b *TransportWrapperBuilder) Build() (result *TransportWrapper, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.headerLevel < 0 {
		err = fmt.Errorf(
			"header level %d isn't valid, it must be greater than or equal to 0",
			b.headerLevel,
		)
		return
	}
	if b.bodyLevel < 0 {
		err = fmt.Errorf(
			"body level %d isn't valid, it must be greater than or equal to 0",
			b.bodyLevel,
		)
		return
	}

	// Create and populate the object:
	result = &TransportWrapper{
		headerLogger: b.logger.V(b.headerLevel),
		bodyLogger:   b.logger.V(b.bodyLevel),
	}

	return
}

// Wrap creates a round tripper on top of the given one that writes to the log the details of
// requests and responses.
func (w *TransportWrapper) Wrap(transport http.RoundTripper) http.RoundTripper {
	return &roundTripper{
		headerLogger: w.headerLogger,
		bodyLogger:   w.bodyLogger,
		wrapped:      transport,
	}
}

// Make sure that we implement the http.RoundTripper interface:
var _ http.RoundTripper = (*roundTripper)(nil)

// RoundTrip is he implementation of the http.RoundTripper interface.
func (t *roundTripper) RoundTrip(request *http.Request) (response *http.Response, err error) {
	// Generate an unique identifier for this request, so that it will be easier to correlate it
	// with the response:
	id := uuid.NewString()

	// Write the details of the request:
	t.dumpRequest(request, id)

	// Replace the request body with a reader that writes to the log:
	if t.bodyLogger.Enabled() && request.Body != nil {
		request.Body = &requestReader{
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

	// Replace the response body with a reader that writes to the log:
	if t.bodyLogger.Enabled() && response.Body != nil {
		response.Body = &responseReader{
			logger: t.bodyLogger,
			id:     id,
			reader: response.Body,
		}
	}

	// Write the details of the response:
	t.dumpResponse(response, id)

	return
}

func (t *roundTripper) dumpRequest(request *http.Request, id string) {
	t.headerLogger.Info(
		"Sending request header",
		"id", id,
		"method", request.Method,
		"url", request.URL,
		"host", request.Host,
		"headers", request.Header,
	)
}

func (t *roundTripper) dumpResponse(response *http.Response, id string) {
	t.headerLogger.Info(
		"Received response header",
		"id", id,
		"protocol", response.Proto,
		"status", response.Status,
		"code", response.StatusCode,
		"headers", response.Header,
	)
}

func (r *requestReader) Read(p []byte) (n int, err error) {
	n, err = r.reader.Read(p)
	eof := errors.Is(err, io.EOF)
	if err == nil || eof {
		r.logger.Info(
			"Sending request body",
			"id", r.id,
			"n", n,
			"eof", eof,
		)
	}
	return
}

func (r *requestReader) Close() error {
	return r.reader.Close()
}

func (r *responseReader) Read(p []byte) (n int, err error) {
	n, err = r.reader.Read(p)
	eof := errors.Is(err, io.EOF)
	if err == nil || eof {
		r.logger.Info(
			"Received response body",
			"id", r.id,
			"n", n,
			"eof", eof,
		)
	}
	return
}

func (r *responseReader) Close() error {
	return r.reader.Close()
}
