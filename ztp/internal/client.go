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
	"os"
	"path/filepath"

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

// Client builder contains the data and logic needed to create a Kubernetes API client that
// implements the controller-runtime WithWatch interface. Don't create instances of this type
// directly, use the NewClient function instead.
type ClientBuilder struct {
	logger     logr.Logger
	env        map[string]string
	kubeconfig any
}

// NewClient creates a builder that can then be used to configure and create a Kubernetes API client
// that implements the controller-runtime WithWatch interface.
func NewClient() *ClientBuilder {
	return &ClientBuilder{}
}

// SetLogger sets the logger that the client will use to write to the log.
func (b *ClientBuilder) SetLogger(value logr.Logger) *ClientBuilder {
	b.logger = value
	return b
}

// SetEnv sets the environment variables.
func (b *ClientBuilder) SetEnv(value map[string]string) *ClientBuilder {
	b.env = value
	return b
}

// SetKubeconfig sets the bytes of the kubeconfig file that will be used to create the client. The
// value can be an array of bytes containing the configuration data or a string containing the name
// of a file. This is optionaln, and if not specified then the configuration will be loaded from the
// typical default locations: the `~/.kube/config` file, the `KUBECONFIG` environment variable, etc.
func (b *ClientBuilder) SetKubeconfig(value any) *ClientBuilder {
	b.kubeconfig = value
	return b
}

// Build uses the data stored in the builder to configure and create a new Kubernetes API client.
func (b *ClientBuilder) Build() (result clnt.WithWatch, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	switch b.kubeconfig.(type) {
	case nil, []byte, string:
	default:
		err = fmt.Errorf(
			"kubeconfig must nil, an array of bytes or a file name, but it is of type %T",
			b.kubeconfig,
		)
		return
	}

	// Load the configuration:
	config, err := b.loadConfig()
	if err != nil {
		err = fmt.Errorf("failed to load configuration: %v", err)
		return
	}

	// Create the client:
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
	// Load the configuration:
	var restCfg *rest.Config
	if b.kubeconfig != nil {
		restCfg, err = b.loadExplicitConfig()
		if err != nil {
			return
		}
	} else {
		restCfg, err = b.loadDefaultConfig()
		if err != nil {
			return
		}
	}

	// Wrap the REST transport so that the details of the requests and responses are written to
	// the log:
	loggingWrapper, err := logging.NewTransportWrapper().
		SetLogger(b.logger).
		Build()
	if err != nil {
		return
	}
	restCfg.WrapTransport = loggingWrapper.Wrap

	// Return the resulting REST config:
	result = restCfg
	return
}

// loadDefaultConfig loads the configuration from the typical default locations, the
// `~/.kube/config` file, the `KUBECONFIG` variable, etc.
func (b *ClientBuilder) loadDefaultConfig() (result *rest.Config, err error) {
	var cfgFile string
	if b.env != nil {
		cfgFile = b.env["KUBECONFIG"]
	}
	if cfgFile == "" {
		var homeDir string
		homeDir, err = os.UserHomeDir()
		if err != nil {
			return
		}
		cfgFile = filepath.Join(homeDir, ".kube", homeDir)
	}
	cfgData, err := os.ReadFile(cfgFile)
	if errors.Is(err, os.ErrNotExist) {
		err = fmt.Errorf("kubeconfig file '%s' doesn't exist", cfgFile)
		return
	}
	if err != nil {
		err = fmt.Errorf("failed to read kubeconfig file '%s': %v", cfgFile, err)
		return
	}
	config, err := clientcmd.NewClientConfigFromBytes(cfgData)
	if err != nil {
		err = fmt.Errorf("failed to parse kubeconfig file '%s': %v", cfgFile, err)
		return
	}
	result, err = config.ClientConfig()
	return
}

// loadExplicitConfig loads the configuration from the kubeconfig data set explicitly in the
// builder.
func (b *ClientBuilder) loadExplicitConfig() (result *rest.Config, err error) {
	var clientCfg clientcmd.ClientConfig
	switch typedCfg := b.kubeconfig.(type) {
	case []byte:
		clientCfg, err = clientcmd.NewClientConfigFromBytes(typedCfg)
		if err != nil {
			return
		}
	case string:
		var cfgData []byte
		cfgData, err = os.ReadFile(typedCfg)
		if err != nil {
			return
		}
		clientCfg, err = clientcmd.NewClientConfigFromBytes(cfgData)
		if err != nil {
			return
		}
	default:
		err = fmt.Errorf(
			"kubeconfig must be an array of bytes or a file name, but it is of type %T",
			b.kubeconfig,
		)
		return
	}
	result, err = clientCfg.ClientConfig()
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
