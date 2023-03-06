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
	"bytes"
	"context"
	"fmt"
	"io"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	apiwatch "k8s.io/apimachinery/pkg/watch"
	"k8s.io/utils/pointer"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Watch", func() {
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
			SetLevel(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

	})

	It("Fails if kind does't exist", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Close()
			Expect(err).ToNot(HaveOccurred())
		}()

		// Try to create the watch using a GVK that doesn't exist:
		list := &unstructured.Unstructured{}
		list.SetGroupVersionKind(schema.GroupVersionKind{
			Group:   "badgroup",
			Version: "v1",
			Kind:    "BadKindList",
		})
		watch, err := client.Watch(ctx, list)
		Expect(err).To(HaveOccurred())
		Expect(watch).To(BeNil())
	})

	It("Fails if option isn't supported", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Close()
			Expect(err).ToNot(HaveOccurred())
		}()

		// Try to create the watch using a matching field that doesn't exist:
		list := &corev1.PodList{}
		watch, err := client.Watch(ctx, list, clnt.MatchingFields{
			"myField": "myValue",
		})
		Expect(err).To(HaveOccurred())
		Expect(watch).To(BeNil())
	})

	It("Accepts options", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Close()
			Expect(err).ToNot(HaveOccurred())
		}()

		// Try to create the watch using a matching field that doesn't exist:
		list := &corev1.PodList{}
		watch, err := client.Watch(ctx, list, clnt.MatchingFields{
			"metadata.name": "my-pod",
		})
		Expect(err).ToNot(HaveOccurred())
		Expect(watch).ToNot(BeNil())
	})

	It("Closes channel if explicitly stopped", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Close()
			Expect(err).ToNot(HaveOccurred())
		}()

		// Create the watch:
		list := &corev1.PodList{}
		watch, err := client.Watch(ctx, list)
		Expect(err).ToNot(HaveOccurred())
		Expect(watch).ToNot(BeNil())

		// Stop the watch and Wait till the channel is closed:
		watch.Stop()
		channel := watch.ResultChan()
		Eventually(channel).Should(BeClosed())
	})

	It("Restarts if underlying watch is closed by server", func() {
		// Create a logger that writes to a buffer in memory:
		buffer := &bytes.Buffer{}
		logger, err := logging.NewLogger().
			SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
			SetLevel(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Close()
			Expect(err).ToNot(HaveOccurred())
		}()

		// Create a namespace and remember to remove it:
		namespace := &corev1.Namespace{
			ObjectMeta: metav1.ObjectMeta{
				Name: fmt.Sprintf("my-%s", uuid.NewString()),
			},
		}
		err = client.Create(ctx, namespace)
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := client.Delete(ctx, namespace)
			Expect(err).ToNot(HaveOccurred())
		}()

		// Start watching the configmap and set explicitly a short timeout for the watch so
		// that the server will close it quickly.
		list := &corev1.ConfigMapList{}
		watch, err := client.Watch(
			ctx,
			list,
			clnt.InNamespace(namespace.Name),
			clnt.MatchingFields{
				"metadata.name": "my",
			},
			&clnt.ListOptions{
				Raw: &metav1.ListOptions{
					TimeoutSeconds: pointer.Int64(1),
				},
			},
		)
		Expect(err).ToNot(HaveOccurred())
		defer watch.Stop()

		// Create the object and wait for the added event:
		object := &corev1.ConfigMap{
			ObjectMeta: metav1.ObjectMeta{
				Namespace: namespace.Name,
				Name:      "my",
			},
		}
		err = client.Create(ctx, object)
		Expect(err).ToNot(HaveOccurred())
		Eventually(func(g Gomega) {
			event := <-watch.ResultChan()
			g.Expect(event.Type).To(Equal(apiwatch.Added))
		}).Should(Succeed())

		// Delete the object and save the events produced:
		err = client.Delete(ctx, object)
		Expect(err).ToNot(HaveOccurred())
		Eventually(func(g Gomega) {
			event, ok := <-watch.ResultChan()
			g.Expect(ok).To(BeTrue())
			Expect(event.Type).To(Equal(apiwatch.Deleted))
		})
	})
})
