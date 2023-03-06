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
	"regexp"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
)

// TransportWrapperBuilder contains the data and logic needed to build a transport wrapper that
// dumps to the log the details of HTTP requests and responses. Don't create instances of this type
// directly, use the NewLoggingTransportWrapper function instead.
type TransportWrapperBuilder struct {
	logger       logr.Logger
	headers      bool
	bodies       bool
	excludeSpecs []any
	flags        *pflag.FlagSet
}

// transportWrapperObject contains the data needed by the transport wrapper, like the logger and
// settings. The wrapper functoin returned to the user is the `do` method of this object.
type transportWrapperObject struct {
	logger      logr.Logger
	headers     bool
	bodies      bool
	excludeFunc func(*http.Request) bool
}

// roundTripper is an implementation of the http.RoundTripper interface that writes to the log the
// details of the requests and responses.
type roundTripper struct {
	logger      logr.Logger
	headers     bool
	bodies      bool
	excludeFunc func(*http.Request) bool
	wrapped     http.RoundTripper
}

type requestReader struct {
	logger logr.Logger
	reader io.ReadCloser
}

type responseReader struct {
	logger logr.Logger
	reader io.ReadCloser
}

// NewTransportWrapper creates a builder that can then be used to configure and create a logging
// transport wrapper.
func NewTransportWrapper() *TransportWrapperBuilder {
	return &TransportWrapperBuilder{}
}

// SetLogger sets the logger that will be used to write request and response details to the log.
// This is mandatory.
func (b *TransportWrapperBuilder) SetLogger(value logr.Logger) *TransportWrapperBuilder {
	b.logger = value
	return b
}

// SetHeaders indicates if HTTP headers should be included in log messages. The default is to not include them.
func (b *TransportWrapperBuilder) SetHeaders(value bool) *TransportWrapperBuilder {
	b.headers = value
	return b
}

// SetBodies indicates if details about the HTTP bodies should be included in log messages. The
// default is to not include them.
func (b *TransportWrapperBuilder) SetBodies(value bool) *TransportWrapperBuilder {
	b.bodies = value
	return b
}

// AddExcludeFunc adds a function that will be called to decide if requests should excluded. If the
// function returns `true` then the request will not be written to the log. If multiple functions
// are added then the request will be excluded if any of the functions returns true. If no functions
// are added then no request will be excluded.
func (b *TransportWrapperBuilder) AddExcludeFunc(
	value func(*http.Request) bool) *TransportWrapperBuilder {
	b.excludeSpecs = append(b.excludeSpecs, value)
	return b
}

// SetExcludeFunc sets a function that will be called to decide if requests should excluded. If the
// function returns `true` then the request will not be written to the log. This removes any exclude
// function previously added with the AddExcludeFunc method.
func (b *TransportWrapperBuilder) SetExcludeFunc(
	value func(*http.Request) bool) *TransportWrapperBuilder {
	b.excludeSpecs = []any{value}
	return b
}

// AddExclude adds a regular expression that will be used to decide if a request should be excluded.
// Note that this is equivalent to creating a function that checks the regular expression and then
// adding it with the AddExcludedFunc method.
func (b *TransportWrapperBuilder) AddExclude(value string) *TransportWrapperBuilder {
	b.excludeSpecs = append(b.excludeSpecs, value)
	return b
}

// SetExclude sets a regular expression that will be used to decide if a request should be excluded.
// Note that this is equivalent to creating a function that checks the regular expression and then
// setting it with the SetExcluede method.
func (b *TransportWrapperBuilder) SetExclude(value string) *TransportWrapperBuilder {
	b.excludeSpecs = []any{value}
	return b
}

// SetFlags sets the command line flags that should be used to configure the logger. This is
// optional.
func (b *TransportWrapperBuilder) SetFlags(flags *pflag.FlagSet) *TransportWrapperBuilder {
	b.flags = flags
	if flags != nil {
		if flags.Changed(headersFlagName) {
			value, err := flags.GetBool(headersFlagName)
			if err == nil {
				b.SetHeaders(value)
			}
		}
		if flags.Changed(bodiesFlagName) {
			value, err := flags.GetBool(bodiesFlagName)
			if err == nil {
				b.SetBodies(value)
			}
		}
	}
	return b
}

// Build uses the data stored in the builder to create and configure a new logging transport
// wrapper.
func (b *TransportWrapperBuilder) Build() (result func(http.RoundTripper) http.RoundTripper,
	err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}

	// Create the functions that check if request should be excluded:
	excludeFunc, err := b.createExcludeFunc()
	if err != nil {
		return
	}

	// Create and populate the object:
	object := &transportWrapperObject{
		logger:      b.logger,
		headers:     b.headers,
		bodies:      b.bodies,
		excludeFunc: excludeFunc,
	}
	result = object.do
	return
}

func (b *TransportWrapperBuilder) createExcludeFunc() (result func(*http.Request) bool, err error) {
	excludeFuncs := make([]func(*http.Request) bool, len(b.excludeSpecs))
	for i, excludeSpec := range b.excludeSpecs {
		switch typed := excludeSpec.(type) {
		case string:
			var excludeRE *regexp.Regexp
			excludeRE, err = regexp.Compile(typed)
			if err != nil {
				err = fmt.Errorf(
					"failed to compile exclude regular expression '%s': %v",
					typed, err,
				)
				return
			}
			excludeFuncs[i] = func(request *http.Request) bool {
				return excludeRE.MatchString(request.URL.Path)
			}
		case func(*http.Request) bool:
			excludeFuncs[i] = typed
		default:
			err = fmt.Errorf(
				"expected regular expression or function but found %T",
				typed,
			)
			return
		}
	}
	result = func(request *http.Request) bool {
		for _, excludeFunc := range excludeFuncs {
			if excludeFunc(request) {
				return true
			}
		}
		return false
	}
	return
}

// do is the wrapper function that will be returned to the user; it creates a round tripper on top
// of the given one that writes to the log the details of requests and responses.
func (w *transportWrapperObject) do(transport http.RoundTripper) http.RoundTripper {
	return &roundTripper{
		logger:      w.logger,
		headers:     w.headers,
		bodies:      w.bodies,
		excludeFunc: w.excludeFunc,
		wrapped:     transport,
	}
}

// Make sure that we implement the http.RoundTripper interface:
var _ http.RoundTripper = (*roundTripper)(nil)

// RoundTrip is he implementation of the http.RoundTripper interface.
func (t *roundTripper) RoundTrip(request *http.Request) (response *http.Response, err error) {
	// Call the wrapped transport and return inmediately if the request should be excluded:
	if t.excludeFunc(request) {
		response, err = t.wrapped.RoundTrip(request)
		return
	}

	// Write the details of the request:
	t.dumpRequest(request)

	// Replace the request body with a reader that writes to the log:
	if t.bodies && request.Body != nil {
		request.Body = &requestReader{
			logger: t.logger,
			reader: request.Body,
		}
	}

	// Call the wrapped transport:
	response, err = t.wrapped.RoundTrip(request)
	if err != nil {
		return
	}

	// Replace the response body with a reader that writes to the log:
	if t.bodies && response.Body != nil {
		response.Body = &responseReader{
			logger: t.logger,
			reader: response.Body,
		}
	}

	// Write the details of the response:
	t.dumpResponse(response)

	return
}

func (t *roundTripper) dumpRequest(request *http.Request) {
	fields := []any{
		"method", request.Method,
		"url", request.URL,
	}
	if t.headers {
		fields = append(fields, "headers", request.Header)
	}
	t.logger.V(2).Info("Sending request", fields...)
}

func (t *roundTripper) dumpResponse(response *http.Response) {
	fields := []any{
		"code", response.StatusCode,
	}
	if t.headers {
		fields = append(fields, "headers", response.Header)
	}
	t.logger.V(2).Info("Received response", fields...)
}

func (r *requestReader) Read(p []byte) (n int, err error) {
	n, err = r.reader.Read(p)
	eof := errors.Is(err, io.EOF)
	if err == nil || eof {
		r.logger.V(2).Info(
			"Sending body",
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
		r.logger.V(2).Info(
			"Received body",
			"n", n,
			"eof", eof,
		)
	}
	return
}

func (r *responseReader) Close() error {
	return r.reader.Close()
}
