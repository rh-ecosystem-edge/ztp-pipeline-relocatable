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

package testing

import (
	"context"
	"sync"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"
	mngr "sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

// Reconciler is a simplified version of the controller runtime reconciler interface intended for
// use in tests. The function will be called passing the object already loaded.
type Reconciler func(context.Context, *unstructured.Unstructured)

// ManagerBuilder contains the data and logic needs to build a fake controller manager intended for
// tests. Don't create instances of this type directly, use the NewManager function instead.
type ManagerBuilder struct {
	logger logr.Logger
	gvks   []schema.GroupVersionKind
}

// Manager is a simplified controller manager intended for tests. Instead of creating types that
// implement the reconcile.Reconciler the user creates simple functions of the Reconciler type that
// can be registered during the execution of the test. These functions will be called with the
// object already retrieved, and only if that object hasn't been already marked for deletion. For
// example, to write a simple reconciler that moves bare metal hosts to the 'provisioned' state:
//
//	var manager *Manager
//
//	BeforeEach(func() {
//		manager = NewManager().
//			SetLogger(logger).
//			AddGVK(gvk).
//			Build()
//	})
//
//	AfterEach(func() {
//		manager.Close()
//	})
//
//	It("Does something", func() {
//		// Add the reconciler that changes the state of bare metal hosts:
//		manager.Add(gvk, func(ctx context.Context, object *unstructured.Unstructured) {
//			update := object.DeepCopy()
//			err := mergo.Map(&update.Object, map[string]any{
//				"status": map[string]any{
//					"provisioning": map[string]any{
//						"state": "provisioned",
//					},
//				},
//			})
//			Expect(err).ToNot(HaveOccurred())
//			err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
//			Expect(err).ToNot(HaveOccurred())
//		})
//	})
type Manager struct {
	lock        *sync.Mutex
	logger      logr.Logger
	client      clnt.Client
	reconcilers map[schema.GroupVersionKind][]Reconciler
	ctx         context.Context
	cancel      context.CancelFunc
}

// NewManager creates a simplified controller manager intended for tests.
func NewManager() *ManagerBuilder {
	return &ManagerBuilder{}
}

// SetLogger sets the logger that will be used by this manager. This is mandatory.
func (b *ManagerBuilder) SetLogger(value logr.Logger) *ManagerBuilder {
	b.logger = value
	return b
}

// AddGVK adds a GVK that the manager will watch.
func (b *ManagerBuilder) AddGVK(value schema.GroupVersionKind) *ManagerBuilder {
	b.gvks = append(b.gvks, value)
	return b
}

// Build uses the data stored in the builder to configure and create a new controller manager.
func (b *ManagerBuilder) Build() *Manager {
	// Check parameters:
	if b.logger.GetSink() == nil {
		Fail("logger is mandatory")
		return nil
	}
	if len(b.gvks) == 0 {
		Fail("at least one GVK is required")
		return nil
	}

	// Load the configuration:
	config := b.loadConfig()

	// Create the controller manager:
	manager, err := mngr.New(config, mngr.Options{
		Logger:             b.logger,
		MetricsBindAddress: "0",
	})
	Expect(err).ToNot(HaveOccurred())

	// Create the object:
	m := &Manager{
		lock:   &sync.Mutex{},
		logger: b.logger,
		client: manager.GetClient(),
	}

	// Create the controllers:
	for _, gvk := range b.gvks {
		b.createController(m, manager, gvk)
	}

	// Initialize the reconcilers:
	m.reconcilers = make(map[schema.GroupVersionKind][]Reconciler)
	for _, gvk := range b.gvks {
		m.reconcilers[gvk] = []Reconciler{}
	}

	// Start the manager:
	m.ctx, m.cancel = context.WithCancel(context.Background())
	go func() {
		defer GinkgoRecover()
		err := manager.Start(m.ctx)
		Expect(err).ToNot(HaveOccurred())
	}()

	// Return the object:
	return m
}

func (b *ManagerBuilder) loadConfig() *rest.Config {
	// Load the configuration:
	config := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		clientcmd.NewDefaultClientConfigLoadingRules(),
		&clientcmd.ConfigOverrides{},
	)
	result, err := config.ClientConfig()
	Expect(err).ToNot(HaveOccurred())

	// Wrap the REST transport so that the details of the requests and responses are written to
	// the log:
	wrapper, err := logging.NewTransportWrapper().
		SetLogger(b.logger).
		Build()
	Expect(err).ToNot(HaveOccurred())
	result.WrapTransport = wrapper.Wrap

	return result
}

func (b *ManagerBuilder) createController(m *Manager, manager mngr.Manager,
	gvk schema.GroupVersionKind) {
	object := &unstructured.Unstructured{}
	object.SetGroupVersionKind(gvk)
	err := builder.ControllerManagedBy(manager).
		For(object).
		Complete(&reconcilerAdapter{
			m:   m,
			gvk: gvk,
		})
	Expect(err).ToNot(HaveOccurred())
}

// AddReconciler adds a reconciler function for the given GKV. It will be executed after all
// previous reconciler for the same GVK.
func (m *Manager) AddReconciler(gvk schema.GroupVersionKind, reconciler Reconciler) {
	m.lock.Lock()
	defer m.lock.Unlock()
	reconcilers, ok := m.reconcilers[gvk]
	ExpectWithOffset(1, ok).To(BeTrue(),
		"Failed to add reconciler because GVK '%s' wasn't registered when the "+
			"manager was created",
		gvk,
	)
	reconcilers = append(reconcilers, reconciler)
	m.reconcilers[gvk] = reconcilers
}

// SetReconciler sets a reconciler function for the given GKV. All previously existing reconciler
// functions will be removed.
func (m *Manager) SetReconciler(gvk schema.GroupVersionKind, reconciler Reconciler) {
	m.lock.Lock()
	defer m.lock.Unlock()
	_, ok := m.reconcilers[gvk]
	ExpectWithOffset(1, ok).To(BeTrue(),
		"Failed to set reconciler because GVK '%s' wasn't registered when the "+
			"manager was created",
		gvk,
	)
	m.reconcilers[gvk] = []Reconciler{reconciler}
}

// Close stops all the controller and releases all the resources used by this manager.
func (m *Manager) Close() {
	if m != nil {
		m.cancel()
	}
}

// reconcilerAdapter implements the controller runtime reconciler interface calling the simple
// reconcile functions that are registered with the fake controller manager.
type reconcilerAdapter struct {
	m      *Manager
	gvk    schema.GroupVersionKind
	client clnt.Client
}

func (a *reconcilerAdapter) Reconcile(ctx context.Context,
	request reconcile.Request) (result reconcile.Result, err error) {
	defer GinkgoRecover()

	// Load the object:
	object := &unstructured.Unstructured{}
	object.SetGroupVersionKind(a.gvk)
	err = a.client.Get(ctx, request.NamespacedName, object)
	if err != nil {
		return
	}
	if object.GetDeletionTimestamp() != nil {
		return
	}

	// Find the reconciler functions:
	var reconcilers []Reconciler
	func() {
		a.m.lock.Lock()
		defer a.m.lock.Unlock()
		reconcilers = a.m.reconcilers[a.gvk]
		if reconcilers == nil {
			return
		}
	}()

	// Run the reconciler functions:
	for _, reconciler := range reconcilers {
		reconciler(ctx, object)
	}

	return
}

func (a *reconcilerAdapter) InjectClient(client clnt.Client) error {
	a.client = client
	return nil
}
