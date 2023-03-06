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
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	"golang.org/x/crypto/ssh"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	apiwatch "k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/utils/strings/slices"
	"sigs.k8s.io/controller-runtime/pkg/client"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

// Client builder contains the data and logic needed to create a Kubernetes API client that
// implements the controller-runtime WithWatch interface. Don't create instances of this type
// directly, use the NewClient function instead.
type ClientBuilder struct {
	logger         logr.Logger
	kubeconfig     any
	wrappers       []func(http.RoundTripper) http.RoundTripper
	loggingWrapper func(http.RoundTripper) http.RoundTripper
	sshServers     []string
	sshUser        string
	sshKey         []byte
	flags          *pflag.FlagSet
}

// Client is an implementtion of the controller-runtime WithWatch interface with additional
// functionality, like the capability to connect using an SSH tunnel.

type Client struct {
	logger   logr.Logger
	delegate clnt.WithWatch
	tunnel   *ssh.Client
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

// AddWrapper adds a function that will be called to wrap the HTTP transport. When multiple wrappers
// are added they will be called in the the reverse order, so that the request processing logic of
// those wrappers will be executed in the right order. For example, example if you want to add a
// wrapper that adds a `X-My` to the request header, and then another wrapper that reads that header
// you should add them in this order:
//
//	client, err := NewClient().
//		SetLogger(logger).
//		AddTransportWrapper(addMyHeader).
//		AddTransportWrapper(readMyHeader).
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
func (b *ClientBuilder) AddWrapper(value func(http.RoundTripper) http.RoundTripper) *ClientBuilder {
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

// SetKubeconfig sets the bytes of the kubeconfig file that will be used to create the client. The
// value can be an array of bytes containing the configuration data or a string containing the name
// of a file. This is optional, and if not specified then the configuration will be loaded from the
// typical default locations: the `~/.kube/config` file, the `KUBECONFIG` environment variable, etc.
func (b *ClientBuilder) SetKubeconfig(value any) *ClientBuilder {
	b.kubeconfig = value
	return b
}

// AddSSHServer adds the address of the SSH server. When there are multiple SSH servers they will be
// tried in order till one succeeds. The value must be the host name or IP address of the server,
// followed by an optional colon and port number. If no port number is specified the default 22 will
// be used.
func (b *ClientBuilder) AddSSHServer(value string) *ClientBuilder {
	b.sshServers = append(b.sshServers, value)
	return b
}

// AddSSHServers adds the addresses of multiple SSH servers. When there are multiple SSH servers
// they will be tried in order till one succeeds.
func (b *ClientBuilder) AddSSHServers(values ...string) *ClientBuilder {
	b.sshServers = append(b.sshServers, values...)
	return b
}

// SetSSHServer sets the address of the SSH server. Note that this removes any previously configured
// one. If you want to preserve them use the AddSSHServer method. The value must be the host name or
// IP address of the server, followed by an optional colon and port number. If no port number is
// specified the default 22 will be used.
func (b *ClientBuilder) SetSSHServer(value string) *ClientBuilder {
	b.sshServers = []string{value}
	return b
}

// SetSSHServers sets the addresses of multiple SSH servers. Note that this removes any previously
// configured one. If you want to preserve them use the AddSSHServers method. The value must be the
// host name or IP address of the server, followed by an optional colon and port number. If no port
// number is specified the default 22 will be used.
func (b *ClientBuilder) SetSSHServers(values ...string) *ClientBuilder {
	b.sshServers = slices.Clone(values)
	return b
}

// SetSSHUser sets the name of the SSH user. This is mandatory when a SSH server is specified.
func (b *ClientBuilder) SetSSHUser(value string) *ClientBuilder {
	b.sshUser = value
	return b
}

// SetSSHKey sets the SSH key. This is required when the SSH server is specified. The value should
// be a PEM encoded private key.
func (b *ClientBuilder) SetSSHKey(value []byte) *ClientBuilder {
	b.sshKey = value
	return b
}

// SetFlags sets the command line flags that should be used to configure the client. This is
// optional.
func (b *ClientBuilder) SetFlags(flags *pflag.FlagSet) *ClientBuilder {
	b.flags = flags
	return b
}

// Build uses the data stored in the builder to configure and create a new Kubernetes API client.
func (b *ClientBuilder) Build() (result *Client, err error) {
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
	if len(b.sshServers) > 0 {
		if b.sshUser == "" {
			err = errors.New("SSH user is mandatory when SSH server is specified")
			return
		}
		if b.sshKey == nil {
			err = errors.New("SSH key is mandatory when SSH server is specified")
			return
		}
	}

	// Load the configuration:
	config, err := b.loadConfig()
	if err != nil {
		return
	}

	// Create the SSH tunnel and update the configuration to use it:
	var tunnel *ssh.Client
	if len(b.sshServers) > 0 {
		tunnel, err = b.createTunnel()
		if err != nil {
			return
		}
		config.Dial = func(_ context.Context, net, addr string) (conn net.Conn, err error) {
			conn, err = tunnel.Dial(net, addr)
			return
		}
	}

	// Create the client:
	delegate, err := clnt.NewWithWatch(config, clnt.Options{})
	if err != nil {
		return
	}

	// Create and populate the object:
	result = &Client{
		logger:   b.logger,
		delegate: delegate,
	}

	return
}

func (b *ClientBuilder) loadConfig() (result *rest.Config, err error) {
	// Load the configuration:
	var clientCfg clientcmd.ClientConfig
	if b.kubeconfig != nil {
		clientCfg, err = b.loadExplicitConfig()
	} else {
		clientCfg, err = b.loadDefaultConfig()
	}
	if err != nil {
		return
	}
	restCfg, err := clientCfg.ClientConfig()
	if err != nil {
		return
	}

	// Add the logging wrapper:
	loggingWrapper := b.loggingWrapper
	if loggingWrapper == nil {
		loggingWrapper, err = logging.NewTransportWrapper().
			SetLogger(b.logger).
			SetFlags(b.flags).
			AddExclude("^/api(/v1)?$").
			AddExclude("^/apis(/.*)?$").
			Build()
		if err != nil {
			return
		}
	}
	restCfg.Wrap(loggingWrapper)

	// Add the transport wrappers in reverse order, so that the request processing logic will
	// happen in the right order:
	for i := len(b.wrappers) - 1; i >= 0; i-- {
		restCfg.Wrap(b.wrappers[i])
	}

	// Return the resulting REST config:
	result = restCfg
	return
}

// loadDefaultConfig loads the configuration from the typical default locations, the `KUBECONFIG`
// environment variable and the ~/.kube/config` file.
func (b *ClientBuilder) loadDefaultConfig() (result clientcmd.ClientConfig, err error) {
	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	overrides := &clientcmd.ConfigOverrides{}
	result = clientcmd.NewNonInteractiveDeferredLoadingClientConfig(rules, overrides)
	return
}

func (b *ClientBuilder) createTunnel() (result *ssh.Client, err error) {
	// Parse the key:
	key, err := ssh.ParsePrivateKey(b.sshKey)
	if err != nil {
		return
	}

	// Make sure that the servers have a port number:
	servers := slices.Clone(b.sshServers)
	for i, server := range servers {
		if strings.LastIndex(server, ":") == -1 {
			servers[i] += ":22"
		}
	}

	// Try each of the servers till one of them succeeds:
	for _, server := range servers {
		if strings.LastIndex(server, ":") == -1 {
			server += ":22"
		}
		result, err = ssh.Dial("tcp", server, &ssh.ClientConfig{
			User: "core",
			Auth: []ssh.AuthMethod{
				ssh.PublicKeys(key),
			},
			HostKeyCallback: ssh.InsecureIgnoreHostKey(),
			Timeout:         5 * time.Second,
		})
		if err == nil {
			break
		}
		b.logger.Info(
			"Failed to connect to SSH server",
			"server", server,
			"err", err,
		)
	}

	// Fail if there is no result:
	if result == nil {
		if len(servers) == 1 {
			err = fmt.Errorf(
				"failed to connect to SSH server '%s'",
				servers[0],
			)
		} else {
			err = fmt.Errorf(
				"failed to connect to SSH servers %s",
				logging.All(servers),
			)
		}
	}

	return
}

// loadExplicitConfig loads the configuration from the kubeconfig data set explicitly in the
// builder.
func (b *ClientBuilder) loadExplicitConfig() (result clientcmd.ClientConfig, err error) {
	switch typed := b.kubeconfig.(type) {
	case []byte:
		result, err = clientcmd.NewClientConfigFromBytes(typed)
	case string:
		var kcData []byte
		kcData, err = os.ReadFile(typed)
		if err != nil {
			return
		}
		result, err = clientcmd.NewClientConfigFromBytes(kcData)
	default:
		err = fmt.Errorf(
			"kubeconfig must be an array of bytes or a file name, but it is of type %T",
			b.kubeconfig,
		)
	}
	return
}

// Make sure that we implement the controller-runtime interface:
var _ clnt.WithWatch = (*Client)(nil)

func (c *Client) Get(ctx context.Context, key types.NamespacedName, obj clnt.Object,
	opts ...clnt.GetOption) error {
	return c.delegate.Get(ctx, key, obj, opts...)
}

func (c *Client) List(ctx context.Context, list clnt.ObjectList,
	opts ...clnt.ListOption) error {
	return c.delegate.List(ctx, list, opts...)
}

func (c *Client) Create(ctx context.Context, obj clnt.Object, opts ...clnt.CreateOption) error {
	return c.delegate.Create(ctx, obj, opts...)
}

func (c *Client) Delete(ctx context.Context, obj clnt.Object, opts ...clnt.DeleteOption) error {
	return c.delegate.Delete(ctx, obj, opts...)
}

func (c *Client) DeleteAllOf(ctx context.Context, obj clnt.Object,
	opts ...clnt.DeleteAllOfOption) error {
	return c.delegate.DeleteAllOf(ctx, obj, opts...)
}

func (c *Client) Patch(ctx context.Context, obj clnt.Object, patch clnt.Patch,
	opts ...clnt.PatchOption) error {
	return c.delegate.Patch(ctx, obj, patch, opts...)
}

func (c *Client) Update(ctx context.Context, obj clnt.Object, opts ...clnt.UpdateOption) error {
	return c.delegate.Update(ctx, obj, opts...)
}

func (c *Client) Status() clnt.SubResourceWriter {
	return c.delegate.Status()
}

func (c *Client) SubResource(subResource string) clnt.SubResourceClient {
	return c.delegate.SubResource(subResource)
}

func (c *Client) RESTMapper() meta.RESTMapper {
	return c.delegate.RESTMapper()
}

func (c *Client) Scheme() *runtime.Scheme {
	return c.delegate.Scheme()
}

func (c *Client) Watch(ctx context.Context, list clnt.ObjectList,
	options ...clnt.ListOption) (result apiwatch.Interface, err error) {
	gvk := list.GetObjectKind().GroupVersionKind()
	underlying := &restartableWatch{
		logger: c.logger.WithValues(
			"group", gvk.Group,
			"kind", gvk.Kind,
		),
		context: ctx,
		object:  list,
		options: options,
		client:  c,
		stop:    make(chan struct{}),
		events:  make(chan apiwatch.Event),
	}
	err = underlying.createUnderlying()
	if err != nil {
		return
	}
	go underlying.forward()
	result = underlying
	return
}

// DeleteCRDGroup deletes all the custom resource definitions in the given group. Returns the number
// of CRDs actually deleted.
func (c *Client) DeleteCRDGroup(ctx context.Context, group string) (n int, err error) {
	all := &unstructured.UnstructuredList{}
	all.SetGroupVersionKind(CustomResourceDefinitionListGVK)
	err = c.delegate.List(ctx, all)
	if err != nil {
		return
	}
	var matching []*unstructured.Unstructured
	for _, item := range all.Items {
		var (
			key string
			ok  bool
		)
		key, ok, err = unstructured.NestedString(item.Object, "spec", "group")
		if err != nil {
			return
		}
		if !ok || key != group {
			continue
		}
		crd := &unstructured.Unstructured{}
		crd.SetGroupVersionKind(item.GroupVersionKind())
		crd.SetName(item.GetName())
		matching = append(matching, crd)
	}
	c.logger.V(1).Info(
		"CRDs to delete",
		"group", group,
		"count", len(matching),
	)
	if len(matching) == 0 {
		return
	}
	for _, crd := range matching {
		err = c.Delete(ctx, crd)
		if err != nil {
			return
		}
		n++
		c.logger.V(1).Info(
			"Deleted CRD",
			"group", group,
			"name", crd.GetName(),
		)
	}
	return
}

// Close closes the client and releases all the resources it is using. It is specially important to
// call this method when the client is using as SSH tunnel, as otherwise the tunnel will remain
// open.
func (c *Client) Close() error {
	if c.tunnel != nil {
		return c.tunnel.Close()
	}
	return nil
}

// restartableWatch is a wrapper for watch.Interface objects that restarts the underlying watch when
// it is closed without any error.
type restartableWatch struct {
	logger     logr.Logger
	client     *Client
	underlying apiwatch.Interface
	context    context.Context
	object     clnt.ObjectList
	options    []clnt.ListOption
	version    string
	stop       chan struct{}
	events     chan apiwatch.Event
}

func (w *restartableWatch) ResultChan() <-chan apiwatch.Event {
	return w.events
}

// forward forwards events from the underlying watch, and restarts it when it is closed by the
// server.
func (w *restartableWatch) forward() {
	for {
		err := w.forwardUnderlying()
		if os.IsTimeout(err) {
			w.logger.V(2).Info(
				"Watch finished with timeout",
				"error", err,
			)
			return
		}
		if err == os.ErrClosed {
			w.logger.V(2).Info(
				"Watch explicitly closed",
				"error", err,
			)
			return
		}
		if err != nil {
			w.logger.Error(
				err,
				"Watch finished with unexpected error",
			)
			return
		}
		w.logger.V(1).Info("Watch finished without error, will restart it")
		backOff := backoff.NewExponentialBackOff()
		backOff.MaxInterval = time.Minute
		backOff.MaxElapsedTime = 0
		err = backoff.RetryNotify(
			w.createUnderlying,
			backoff.WithContext(backOff, w.context),
			func(err error, delay time.Duration) {
				w.logger.V(1).Info(
					"Failed to create watch, will try again",
					"error", err,
					"delay", delay,
				)
			},
		)
		if err != nil {
			w.logger.Error(err, "Failed to create watch")
			return
		}
		w.logger.V(2).Info("Created watch")
	}
}

// forwardUnderlying forwards events from the underlying watch to our events channel till the
// underlying watch has been closed by the server, till it has been explicitly stopped or till the
// context has expired, whatever happens first.
func (w *restartableWatch) forwardUnderlying() error {
	for {
		select {
		case event, ok := <-w.underlying.ResultChan():
			if !ok {
				return nil
			}
			switch object := event.Object.(type) {
			case clnt.Object:
				w.version = object.GetResourceVersion()
				w.logger.V(2).Info(
					"Received event",
					"type", event.Type,
					"version", w.version,
				)
			default:
				w.logger.V(2).Info(
					"Received event with unknown object type",
					"event_type", event.Type,
					"object_type", fmt.Sprintf("%T", object),
				)
			}
			w.events <- event
		case <-w.stop:
			w.underlying.Stop()
			close(w.events)
			return os.ErrClosed
		case <-w.context.Done():
			w.underlying.Stop()
			close(w.events)
			return w.context.Err()
		}
	}
}

func (w *restartableWatch) createUnderlying() error {
	var err error
	options := &client.ListOptions{}
	options.ApplyOptions(w.options)
	if w.version != "" {
		if options.Raw == nil {
			options.Raw = &metav1.ListOptions{}
		}
		options.Raw.ResourceVersion = w.version
	}
	w.underlying, err = w.client.delegate.Watch(w.context, w.object, options)
	return err
}

func (w *restartableWatch) Stop() {
	close(w.stop)
}
