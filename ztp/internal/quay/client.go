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

package quay

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"

	"github.com/go-logr/logr"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/spf13/pflag"
)

// ClientBuilder contains the data and logic needed to create a client for the Quay REST API. Don't
// create intances of this type directly, use the NewClient function instead.
type ClientBuilder struct {
	logger         logr.Logger
	url            string
	insecure       bool
	token          string
	wrappers       []func(http.RoundTripper) http.RoundTripper
	loggingWrapper func(http.RoundTripper) http.RoundTripper
	flags          *pflag.FlagSet
}

// Client is a client for the Quay REST API. Don't create instances of this type directly, use the
// NewClient function instead.
type Client struct {
	logger logr.Logger
	url    string
	token  string
	client *http.Client
}

// NewClient creates a builder that can then be used to configure and create a client for the Quay
// REST API.
func NewClient() *ClientBuilder {
	return &ClientBuilder{}
}

// SetLogger sets the logger that the client will use to write to the log.
func (b *ClientBuilder) SetLogger(value logr.Logger) *ClientBuilder {
	b.logger = value
	return b
}

// SetURL sets the base URL of the API server.
func (b *ClientBuilder) SetURL(value string) *ClientBuilder {
	b.url = value
	return b
}

// SetToken sets the authentication token that the client will use to send requests.
func (b *ClientBuilder) SetToken(value string) *ClientBuilder {
	b.token = value
	return b
}

// AddWrapper adds a function that will be called to wrap the HTTP transport. When multiple wrappers
// are added they will be called in the the reverse order, so that the request processing logic of
// those wrappers will be executed in the right order. For example, example if you want to add a
// wrapper that adds a `X-My` to the request header, and then another wrapper that reads that header
// you should add them in this order:
//
//	client, err := NewClient().
//		SetLogger(logger).
//		AddWrapper(addMyHeader).
//		AddWrapper(readMyHeader).
//		Build()
//	if err != nil {
//		...
//	}
//
// The opposite happens with response processing logic: it happens in the same order that the
// wrappers were added.
//
// The logging wrapper should not be added with this method, but with the SetLoggingWrapper methods,
// otherwise a default logging wrapper will be automatically added.
func (b *ClientBuilder) AddWrapper(
	value func(http.RoundTripper) http.RoundTripper) *ClientBuilder {
	b.wrappers = append(b.wrappers, value)
	return b
}

// SetLoggingWrapper sets the logging transport wrapper. If this isn't set then a default one will
// be created. Note that this wrapper, either the one explicitly set or the default, will always be
// the last to process requests and the first to process responses.
func (b *ClientBuilder) SetLoggingWrapper(
	value func(http.RoundTripper) http.RoundTripper) *ClientBuilder {
	b.loggingWrapper = value
	return b
}

// SetFlags sets the command line flags that should be used to configure the client. This is
// optional.
func (b *ClientBuilder) SetFlags(flags *pflag.FlagSet) *ClientBuilder {
	b.flags = flags
	return b
}

// SetInsecure sets or clears the flag that allows connections to servers whose certificates can't
// be validated.
func (b *ClientBuilder) SetInsecure(value bool) *ClientBuilder {
	b.insecure = value
	return b
}

// Build uses the data stored in the builder to create a new client for the Quay REST API.
func (b *ClientBuilder) Build() (result *Client, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.url == "" {
		err = errors.New("URL is mandatory")
		return
	}

	// Create the HTTP client:
	client, err := b.createClient()
	if err != nil {
		return
	}

	// Create and populate the object:
	result = &Client{
		logger: b.logger,
		url:    fmt.Sprintf("%s/%s", b.url, "api/v1"),
		token:  b.token,
		client: client,
	}
	return
}

func (b *ClientBuilder) createClient() (result *http.Client, err error) {
	// Create the transport:
	base, err := url.Parse(b.url)
	if err != nil {
		return
	}
	var transport http.RoundTripper
	if strings.EqualFold(base.Scheme, "https") {
		transport = &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: b.insecure,
			},
		}
	} else {
		transport = http.DefaultTransport
	}

	// Apply the logging wrapper:
	loggingWrapper := b.loggingWrapper
	if loggingWrapper == nil {
		loggingWrapper, err = logging.NewTransportWrapper().
			SetLogger(b.logger).
			SetFlags(b.flags).
			Build()
		if err != nil {
			return
		}
	}
	transport = loggingWrapper(transport)

	// Apply the transport wrappers in reverse order, so that the request processing logic will
	// happen in the right order:
	for i := len(b.wrappers) - 1; i >= 0; i-- {
		transport = b.wrappers[i](transport)
	}

	// Create the cookie jar:
	jar, err := cookiejar.New(nil)
	if err != nil {
		return
	}

	// Create the HTTP client:
	result = &http.Client{
		Transport: transport,
		Jar:       jar,
	}
	return
}

// Token returns the authentication token that the client is currently used. This will be the token
// set when the client was created or the token returned during user initialization. Note that it
// will be empty if no token was set during creation and user initialization hasn't been performed.
func (c *Client) Token() string {
	return c.token
}

func (c *Client) post(ctx context.Context, path string, requestObject any,
	responseNew func() any) (responseObject any, err error) {
	requestMethod := http.MethodPost
	requestURL := fmt.Sprintf("%s/%s", c.url, path)
	requestBytes, err := json.Marshal(requestObject)
	if err != nil {
		return
	}
	requestBody := bytes.NewBuffer(requestBytes)
	request, err := http.NewRequestWithContext(ctx, requestMethod, requestURL, requestBody)
	if err != nil {
		return
	}
	request.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		request.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.token))
	}
	c.logger.V(2).Info(
		"Sending request",
		"method", requestMethod,
		"url", requestURL,
		"body", string(requestBytes),
	)
	response, err := c.client.Do(request)
	if err != nil {
		return
	}
	defer response.Body.Close()
	responseBytes, err := io.ReadAll(response.Body)
	if err != nil {
		return
	}
	responseCode := response.StatusCode
	c.logger.V(2).Info(
		"Received response",
		"code", responseCode,
		"body", string(responseBytes),
	)
	responseType := response.Header.Get("Content-Type")
	if responseCode >= 200 && responseCode < 400 {
		if responseNew != nil {
			responseObject = responseNew()
			if responseType == "application/json" {
				err = json.Unmarshal(responseBytes, responseObject)
				if err != nil {
					return
				}
			}
		}
		return
	}
	responseErr := &Error{}
	err = json.Unmarshal(responseBytes, responseErr)
	if err != nil {
		if responseType == "application/json" {
			return
		}
	}
	if responseErr.Status == 0 {
		responseErr.Status = responseCode
	}
	err = responseErr
	return
}
