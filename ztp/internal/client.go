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

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"
)

// Client builder contains the data and logic needed to create a Kubernetes API client that
// implements the controller-runtime WithWatch interface. Don't create instances of this type
// directly, use the NewClient function instead.
type ClientBuilder struct {
	logger logr.Logger
}

// NewClient creates a builder that can then be used to configure and create a Kubernetes API client
// that implements the controller-runtime WithWatch interface.
func NewClient() *ClientBuilder {
	return &ClientBuilder{}
}

// Logger sets the logger that the client will use to write to the log.
func (b *ClientBuilder) Logger(value logr.Logger) *ClientBuilder {
	b.logger = value
	return b
}

// Build uses the data stored in the builder to configure and create a new Kubernetes API client.
func (b *ClientBuilder) Build() (result clnt.WithWatch, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}

	// Load the configuration:
	config, err := b.loadConfig()
	if err != nil {
		err = fmt.Errorf("failed to load configuration: %v", err)
		return
	}

	// Create the underlying client that we will delgate to:
	delegate, err := clnt.NewWithWatch(config, clnt.Options{})
	if err != nil {
		err = fmt.Errorf("failed to create delegate: %v", err)
		return
	}

	// Create and populate the object:
	result = &client{
		logger:   b.logger,
		delegate: delegate,
	}

	return
}

func (b *ClientBuilder) loadConfig() (result *rest.Config, err error) {
	// Create the configuration:
	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	overrides := &clientcmd.ConfigOverrides{}
	config := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(rules, overrides)
	result, err = config.ClientConfig()
	if err != nil {
		return
	}

	// Wrap the transport so that the details of the requests and responses are written to the
	// log:
	wrapper, err := NewLoggingTransportWrapper().
		SetLogger(b.logger).
		SetHeaderV(1).
		SetBodyV(2).
		Build()
	if err != nil {
		return
	}
	result.WrapTransport = wrapper.Wrap

	return
}

// client is an implementtion of the controller-runtime WithWatch interface that delegates all the
// calls to another implementation of that interface. It is intended to add additional behaviour,
// like logging.
type client struct {
	logger   logr.Logger
	delegate clnt.WithWatch
}

// Make sure that we implement the interface:
var _ clnt.WithWatch = (*client)(nil)

func (c *client) Get(ctx context.Context, key types.NamespacedName, obj clnt.Object,
	opts ...clnt.GetOption) error {
	return c.delegate.Get(ctx, key, obj, opts...)
}

func (c *client) List(ctx context.Context, list clnt.ObjectList,
	opts ...clnt.ListOption) error {
	return c.delegate.List(ctx, list, opts...)
}

func (c *client) Create(ctx context.Context, obj clnt.Object, opts ...clnt.CreateOption) error {
	return c.delegate.Create(ctx, obj, opts...)
}

func (c *client) Delete(ctx context.Context, obj clnt.Object, opts ...clnt.DeleteOption) error {
	return c.delegate.Delete(ctx, obj, opts...)
}

func (c *client) DeleteAllOf(ctx context.Context, obj clnt.Object,
	opts ...clnt.DeleteAllOfOption) error {
	return c.delegate.DeleteAllOf(ctx, obj, opts...)
}

func (c *client) Patch(ctx context.Context, obj clnt.Object, patch clnt.Patch,
	opts ...clnt.PatchOption) error {
	return c.delegate.Patch(ctx, obj, patch, opts...)
}

func (c *client) Update(ctx context.Context, obj clnt.Object, opts ...clnt.UpdateOption) error {
	return c.delegate.Update(ctx, obj, opts...)
}

func (c *client) Status() clnt.SubResourceWriter {
	return c.delegate.Status()
}

func (c *client) SubResource(subResource string) clnt.SubResourceClient {
	return c.delegate.SubResource(subResource)
}

func (c *client) RESTMapper() meta.RESTMapper {
	return c.delegate.RESTMapper()
}

func (c *client) Scheme() *runtime.Scheme {
	return c.delegate.Scheme()
}

func (c *client) Watch(ctx context.Context, obj clnt.ObjectList,
	opts ...clnt.ListOption) (watch.Interface, error) {
	return c.delegate.Watch(ctx, obj, opts...)
}
