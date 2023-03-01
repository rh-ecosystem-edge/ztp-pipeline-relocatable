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

package internal

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/text"
)

var _ = Describe("Applier", func() {
	var (
		ctx    context.Context
		logger logr.Logger
		client *Client
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(1).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Get the Kubernetes API client:
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterEach(func() {
		var err error
		if client != nil {
			err = client.Close()
			Expect(err).ToNot(HaveOccurred())
		}
	})

	Describe("Creation", func() {
		var fsys fs.FS

		BeforeEach(func() {
			var tmp string
			tmp, fsys = TmpFS()
			DeferCleanup(func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			})
		})

		It("Can't be created without a logger", func() {
			applier, err := NewApplier().
				SetFS(fsys).
				SetClient(client).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("logger"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(applier).To(BeNil())
		})

		It("Can't be created without a filesystem", func() {
			applier, err := NewApplier().
				SetLogger(logger).
				SetClient(client).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("filesystem"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(applier).To(BeNil())
		})

		It("Can't be created without a client", func() {
			applier, err := NewApplier().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("client"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(applier).To(BeNil())
		})
	})

	Describe("Usage", func() {
		It("Renders a single object", func() {
			// Create the templates filesystem:
			tmp, fsys := TmpFS(
				"objects/my-object.yaml",
				text.Dedent(`
					apiVersion: v1
					kind: Namespace
					metadata:
					  name: my-ns
				`),
			)
			defer func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the applier:
			applier, err := NewApplier().
				SetLogger(logger).
				SetFS(fsys).
				SetDir("objects").
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := applier.Render(ctx, nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(objects).To(HaveLen(1))

			// Verify the object:
			object := objects[0]
			kind := object.GetObjectKind()
			Expect(kind.GroupVersionKind()).To(Equal(schema.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "Namespace",
			}))
			Expect(object.GetName()).To(Equal("my-ns"))
		})

		It("Renders multiple objects", func() {
			// Create the templates filesystem:
			tmp, fsys := TmpFS(
				"objects/my-objects.yaml",
				text.Dedent(`
					apiVersion: v1
					kind: Namespace
					metadata:
					  name: my-ns

					---

					apiVersion: v1
					kind: Secret
					metadata:
					  namespace: my-ns
					  name: my-secret
					data:
					  my-key: bXktZGF0YQ==

					---

					apiVersion: v1
					kind: ConfigMap
					metadata:
					  namespace: my-ns
					  name: my-config
					data:
					  my-key: my-value
				`),
			)
			defer func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the renderer:
			applier, err := NewApplier().
				SetLogger(logger).
				SetFS(fsys).
				SetDir("objects").
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := applier.Render(ctx, nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(objects).To(HaveLen(3))

			// Verify the first object:
			object := objects[0]
			kind := object.GetObjectKind()
			Expect(kind.GroupVersionKind()).To(Equal(schema.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "Namespace",
			}))
			Expect(object.GetName()).To(Equal("my-ns"))

			// Verify the second object:
			object = objects[1]
			kind = object.GetObjectKind()
			Expect(kind.GroupVersionKind()).To(Equal(schema.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "Secret",
			}))
			Expect(object.GetNamespace()).To(Equal("my-ns"))
			Expect(object.GetName()).To(Equal("my-secret"))

			// Verify the third object:
			object = objects[2]
			kind = object.GetObjectKind()
			Expect(kind.GroupVersionKind()).To(Equal(schema.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "ConfigMap",
			}))
			Expect(object.GetNamespace()).To(Equal("my-ns"))
			Expect(object.GetName()).To(Equal("my-config"))
		})

		It("Supports template constructs", func() {
			// Create the templates filesystem:
			tmp, fsys := TmpFS(
				"objects/my-object.yaml",
				text.Dedent(`
					apiVersion: v1
					kind: ConfigMap
					metadata:
					  namespace: my-ns
					  name: my-config
					data:
					  my-string: "{{ .MyString }}"
					  my-bytes: {{ .MyBytes | base64 }}
					  my-int: {{ .MyInt | json }}
					  my-ip: {{ execute "files/my-ip.txt" . }}
				`),
				"files/my-ip.txt",
				`{{ .MyIP }}`,
			)
			defer func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the applier:
			applier, err := NewApplier().
				SetLogger(logger).
				SetFS(fsys).
				SetDir("objects").
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := applier.Render(ctx, map[string]any{
				"MyString": "my-value",
				"MyBytes":  []byte{1, 2, 3},
				"MyInt":    42,
				"MyIP":     "192.168.122.1",
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(objects).To(HaveLen(1))

			// Verify the object:
			object := objects[0]
			kind := object.GetObjectKind()
			Expect(kind.GroupVersionKind()).To(Equal(schema.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "ConfigMap",
			}))
			Expect(object.GetNamespace()).To(Equal("my-ns"))
			Expect(object.GetName()).To(Equal("my-config"))
			Expect(object.Object).To(HaveKey("data"))
			var data map[string]any
			Expect(object.Object["data"]).To(BeAssignableToTypeOf(data))
			data = object.Object["data"].(map[string]any)
			Expect(data).To(HaveKeyWithValue("my-string", "my-value"))
			Expect(data).To(HaveKeyWithValue("my-bytes", "AQID"))
			Expect(data).To(HaveKeyWithValue("my-int", 42))
			Expect(data).To(HaveKeyWithValue("my-ip", "192.168.122.1"))
		})

		It("Deletes namespace only when objects are gone", func() {
			// Prepare a namespace with an object that has a finalizer, so the applier
			// will have to wait till that finalizer is removed before removing the
			// namespace:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			data := map[string]any{
				"Name": name,
			}
			tmp, fsys := TmpFS(
				"objects.yaml",
				text.Dedent(`
					apiVersion: v1
					kind: Namespace
					metadata: 
					  name: {{ .Name }}
					---
					apiVersion: v1
					kind: ConfigMap
					metadata: 
					  namespace: {{ .Name }}
					  name: my-object
					  finalizers:
					  - my/finalizer
				`),
			)
			defer func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the applier:
			applier, err := NewApplier().
				SetLogger(logger).
				SetFS(fsys).
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			err = applier.Apply(ctx, data)
			Expect(err).ToNot(HaveOccurred())

			// Delete the objects in a separate goroutine with a reasonable timeout.
			// This is needed because the applier will wait till the object is
			// completely deleted, and it won't be till we remove the finalizer.
			waitGroup := &sync.WaitGroup{}
			waitGroup.Add(1)
			defer waitGroup.Wait()
			go func() {
				defer GinkgoRecover()
				ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
				defer cancel()
				err := applier.Delete(ctx, data)
				Expect(err).ToNot(HaveOccurred())
				waitGroup.Done()
			}()

			// Wait till the applier has sent the request to delete the object, so that
			// the object will have the deletion timestamp set.
			object := &corev1.ConfigMap{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      "my-object",
			}
			Eventually(func(g Gomega) bool {
				err = client.Get(ctx, key, object)
				g.Expect(err).ToNot(HaveOccurred())
				return !object.DeletionTimestamp.IsZero()
			}).Should(BeTrue())

			// Check that the namespace hasn't been deleted yet:
			namespace := &corev1.Namespace{}
			key = clnt.ObjectKey{
				Name: name,
			}
			err = client.Get(ctx, key, namespace)
			Expect(err).ToNot(HaveOccurred())
			Expect(namespace.DeletionTimestamp).To(BeZero())

			// Remove the finalizer:
			patched := object.DeepCopy()
			patched.Finalizers = nil
			err = client.Patch(ctx, patched, clnt.MergeFrom(object))
			Expect(err).ToNot(HaveOccurred())

			// Wait till the namespace has been completely deleted:
			Eventually(
				func(g Gomega) bool {
					err = client.Get(ctx, key, namespace)
					if apierrors.IsNotFound(err) {
						return true
					}
					g.Expect(err).ToNot(HaveOccurred())
					return false
				},
				1*time.Minute,
			).Should(BeTrue())
		})

		It("Waits for CRD before creating object", func() {
			// Create the object in a separate goroutine, as it will block waiting for
			// the CRD:
			data := map[string]any{
				"Group": fmt.Sprintf("example-%s.com", uuid.NewString()),
			}
			objectTmp, objectFsys := TmpFS(
				"object.yaml",
				text.Dedent(`
					apiVersion: {{ .Group }}/v1
					kind: Example
					metadata:
					  name: example
				`),
			)
			defer os.RemoveAll(objectTmp)
			waitFlag := &atomic.Bool{}
			objectListener := func(event *ApplierEvent) {
				if event.Type == ApplierWaitingCRD {
					waitFlag.Store(true)
				}
			}
			objectApplier, err := NewApplier().
				SetLogger(logger).
				SetClient(client).
				SetFS(objectFsys).
				SetListener(objectListener).
				Build()
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := objectApplier.Delete(ctx, data)
				Expect(err).ToNot(HaveOccurred())
			}()
			waitGroup := &sync.WaitGroup{}
			waitGroup.Add(1)
			defer waitGroup.Wait()
			go func() {
				defer GinkgoRecover()
				err := objectApplier.Apply(ctx, data)
				Expect(err).ToNot(HaveOccurred())
				waitGroup.Done()
			}()

			// Wait till the object applier is waiting for the CRD:
			Eventually(waitFlag.Load).Should(BeTrue())

			// Create the CRD:
			crdTmp, crdFsys := TmpFS(
				"crd.yaml",
				text.Dedent(`
					apiVersion: apiextensions.k8s.io/v1
					kind: CustomResourceDefinition
					metadata:
					  name: examples.{{ .Group }}
					spec:
					  group: {{ .Group }}
					  names:
					    kind: Example
					    listKind: ExampleList
					    plural: examples
					    singular: example
					  scope: Cluster
					  versions:
					  - name: v1
					    served: true
					    storage: false
					    schema:
					      openAPIV3Schema:
					        type: object
					        x-kubernetes-preserve-unknown-fields: true
					  - name: v2
					    served: true
					    storage: true
					    schema:
					      openAPIV3Schema:
					        type: object
					        x-kubernetes-preserve-unknown-fields: true
				`),
			)
			defer os.RemoveAll(crdTmp)
			crdApplier, err := NewApplier().
				SetLogger(logger).
				SetClient(client).
				SetFS(crdFsys).
				Build()
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := crdApplier.Delete(ctx, data)
				Expect(err).ToNot(HaveOccurred())
			}()
			err = crdApplier.Apply(ctx, data)
			Expect(err).ToNot(HaveOccurred())

			// Wait till the object has been created:
			objectMeta := &metav1.PartialObjectMetadata{}
			objectMeta.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "example.com",
				Version: "v1",
				Kind:    "Example",
			})
			objectKey := clnt.ObjectKey{
				Name: "example",
			}
			Eventually(func() bool {
				return client.Get(ctx, objectKey, objectMeta) != nil
			}).Should(BeTrue())

			// Wait for the applier goroutine to finish:
			waitGroup.Wait()
		})
	})
})
