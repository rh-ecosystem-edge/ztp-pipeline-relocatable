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
	"bytes"
	"errors"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Applier listener", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	DescribeTable(
		"Generates the expected messages",
		func(event *ApplierEvent, msg string) {
			buffer := &bytes.Buffer{}
			listener, err := NewApplierListener().
				SetLogger(logger).
				SetOut(buffer).
				SetErr(buffer).
				Build()
			Expect(err).ToNot(HaveOccurred())
			listener.Func(event)
			Expect(buffer.String()).To(Equal(msg))
		},
		Entry(
			"Namespace created",
			&ApplierEvent{
				Type: ApplierObjectCreated,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Namespace",
						"metadata": map[string]any{
							"name": "my-ns",
						},
					},
				},
			},
			"Created namespace 'my-ns'\n",
		),
		Entry(
			"Namespace deleted",
			&ApplierEvent{
				Type: ApplierObjectDeleted,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Namespace",
						"metadata": map[string]any{
							"name": "my-ns",
						},
					},
				},
			},
			"Deleted namespace 'my-ns'\n",
		),
		Entry(
			"Namespace already exists",
			&ApplierEvent{
				Type: ApplierObjectExist,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Namespace",
						"metadata": map[string]any{
							"name": "my-ns",
						},
					},
				},
			},
			"Namespace 'my-ns' already exists\n",
		),
		Entry(
			"Object created",
			&ApplierEvent{
				Type: ApplierObjectCreated,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Secret",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-secret",
						},
					},
				},
			},
			"Created secret 'my-ns/my-secret'\n",
		),
		Entry(
			"Object deleted",
			&ApplierEvent{
				Type: ApplierObjectDeleted,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Secret",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-secret",
						},
					},
				},
			},
			"Deleted secret 'my-ns/my-secret'\n",
		),
		Entry(
			"Object already exists",
			&ApplierEvent{
				Type: ApplierObjectExist,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Secret",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-secret",
						},
					},
				},
			},
			"Secret 'my-ns/my-secret' already exists\n",
		),
		Entry(
			"Object status updated",
			&ApplierEvent{
				Type: ApplierStatusUpdated,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Pod",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-pod",
						},
					},
				},
			},
			"Updated status of pod 'my-ns/my-pod'\n",
		),
		Entry(
			"Object creation error",
			&ApplierEvent{
				Type: ApplierCreateError,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Pod",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-pod",
						},
					},
				},
				Error: errors.New("my-error"),
			},
			"Failed to create pod 'my-ns/my-pod': my-error\n",
		),
		Entry(
			"Waiting for CRD",
			&ApplierEvent{
				Type: ApplierWaitingCRD,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "Example",
						"metadata": map[string]any{
							"namespace": "my-ns",
							"name":      "my-example",
						},
					},
				},
			},
			"Waiting for CRD before creating example 'my-ns/my-example'\n",
		),
		Entry(
			"Exception in friendly name (CRD instead of custom resource definition)",
			&ApplierEvent{
				Type: ApplierObjectCreated,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "CustomResourceDefinition",
						"metadata": map[string]any{
							"name": "examples.example.com",
						},
					},
				},
			},
			"Created CRD 'examples.example.com'\n",
		),
		Entry(
			"CRD with multiple words",
			&ApplierEvent{
				Type: ApplierObjectCreated,
				Object: &unstructured.Unstructured{
					Object: map[string]any{
						"kind": "SomethingWithMultipleWords",
						"metadata": map[string]any{
							"name": "my-thing",
						},
					},
				},
			},
			"Created something with multiple words 'my-thing'\n",
		),
	)
})
