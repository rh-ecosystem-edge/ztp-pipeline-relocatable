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
	"io/fs"
	"os"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Applier", func() {
	var (
		ctx    context.Context
		logger logr.Logger
		client clnt.WithWatch
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Get the Kubernetes API client:
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
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
				Dedent(`
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
				Dedent(`
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
				Dedent(`
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
	})
})
