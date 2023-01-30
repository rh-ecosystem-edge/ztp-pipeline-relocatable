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
	"os"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Renderer", func() {
	var (
		ctx    context.Context
		logger logr.Logger
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetV(2).
			Build()
		Expect(err).ToNot(HaveOccurred())

	})

	Describe("Creation", func() {
		var engine *templating.Engine

		BeforeEach(func() {
			var err error

			// Create the templates filesystem:
			tmp, fsys := TmpFS()
			DeferCleanup(func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			})

			// Create the templating engine:
			engine, err = templating.NewEngine().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		It("Can't be created without a logger", func() {
			renderer, err := NewRenderer().
				SetTemplates(engine, "a.txt").
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("logger"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(renderer).To(BeNil())
		})

		It("Can't be created without a template engine", func() {
			renderer, err := NewRenderer().
				SetLogger(logger).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("engine"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(renderer).To(BeNil())
		})

		It("Can't be created without at least one template", func() {
			renderer, err := NewRenderer().
				SetLogger(logger).
				SetTemplates(engine).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("names"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(renderer).To(BeNil())
		})
	})

	Describe("Usage", func() {
		It("Renders a single object", func() {
			// Create the templates filesystem:
			tmp, fsys := TmpFS(
				"my-object.yaml",
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

			// Create the templating engine:
			engine, err := templating.NewEngine().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the renderer:
			renderer, err := NewRenderer().
				SetLogger(logger).
				SetTemplates(engine, "my-object.yaml").
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := renderer.Render(ctx, nil)
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
				"my-objects.yaml",
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

			// Create the templating engine:
			engine, err := templating.NewEngine().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the renderer:
			renderer, err := NewRenderer().
				SetLogger(logger).
				SetTemplates(engine, "my-objects.yaml").
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := renderer.Render(ctx, nil)
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
				"my-object.yaml",
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
					  my-ip: {{ execute "my-ip.txt" . }}
				`),
				"my-ip.txt",
				`{{ .MyIP }}`,
			)
			defer func() {
				err := os.RemoveAll(tmp)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the templating engine:
			engine, err := templating.NewEngine().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the renderer:
			renderer, err := NewRenderer().
				SetLogger(logger).
				SetTemplates(engine, "my-object.yaml").
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the objects:
			objects, err := renderer.Render(ctx, map[string]any{
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
			var content *unstructured.Unstructured
			Expect(object).To(BeAssignableToTypeOf(content))
			content = object.(*unstructured.Unstructured)
			Expect(content.Object).To(HaveKey("data"))
			var data map[string]any
			Expect(content.Object["data"]).To(BeAssignableToTypeOf(data))
			data = content.Object["data"].(map[string]any)
			Expect(data).To(HaveKeyWithValue("my-string", "my-value"))
			Expect(data).To(HaveKeyWithValue("my-bytes", "AQID"))
			Expect(data).To(HaveKeyWithValue("my-int", 42))
			Expect(data).To(HaveKeyWithValue("my-ip", "192.168.122.1"))
		})
	})
})
