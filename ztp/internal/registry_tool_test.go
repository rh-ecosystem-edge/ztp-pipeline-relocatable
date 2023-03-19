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
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	"github.com/imdario/mergo"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/ghttp"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Registry tool", func() {
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
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterEach(func() {
		// Close the client:
		err := client.Close()
		Expect(err).ToNot(HaveOccurred())
	})

	Describe("Creation", func() {
		It("Can't be created without a logger", func() {
			tool, err := NewRegistryTool().
				SetClient(client).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("logger"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(tool).To(BeNil())
		})

		It("Can't be created without a client", func() {
			tool, err := NewRegistryTool().
				SetLogger(logger).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("client"))
			Expect(msg).To(ContainSubstring("mandatory"))
			Expect(tool).To(BeNil())
		})
	})

	Describe("Add trusted registry", func() {
		var (
			randomName   string
			jqTool       *jq.Tool
			registryTool *RegistryTool
		)

		BeforeEach(func() {
			// Generate a random name for the image configuration object and for the CA
			// configmap:
			randomName = fmt.Sprintf("my-%s", uuid.NewString())

			// Create the image configuration object:
			configObject := &unstructured.Unstructured{}
			configObject.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "config.openshift.io",
				Version: "v1",
				Kind:    "Image",
			})
			configObject.SetName(randomName)
			configObject.Object["spec"] = map[string]any{}
			err := client.Create(ctx, configObject)
			Expect(err).ToNot(HaveOccurred())

			// Create the JQ tool:
			jqTool, err = jq.NewTool().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create the tool:
			registryTool, err = NewRegistryTool().
				SetLogger(logger).
				SetClient(client).
				SetConfigName(randomName).
				SetConfigmapName(randomName).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			var err error

			// Delete the image configObject object:
			configObject := &unstructured.Unstructured{}
			configObject.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "config.openshift.io",
				Version: "v1",
				Kind:    "Image",
			})
			configObject.SetName(randomName)
			err = client.Delete(ctx, configObject)
			if apierrors.IsNotFound(err) {
				err = nil
			}
			Expect(err).ToNot(HaveOccurred())

			// Delete the configmapObject:
			configmapObject := &corev1.ConfigMap{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: "openshift-config",
					Name:      randomName,
				},
			}
			err = client.Delete(ctx, configmapObject)
			if apierrors.IsNotFound(err) {
				err = nil
			}
			Expect(err).ToNot(HaveOccurred())
		})

		It("Adds first trusted registry", func() {
			// Add the registry:
			err := registryTool.AddTrustedRegistry(
				ctx,
				"my.registry.com",
				[]byte("my-ca"),
			)
			Expect(err).ToNot(HaveOccurred())

			// Check that the image config has been updated:
			configObject := &unstructured.Unstructured{}
			configObject.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "config.openshift.io",
				Version: "v1",
				Kind:    "Image",
			})
			configKey := clnt.ObjectKey{
				Name: randomName,
			}
			err = client.Get(ctx, configKey, configObject)
			Expect(err).ToNot(HaveOccurred())
			var configmapName string
			err = jqTool.Query(
				`.spec.additionalTrustedCA.name`,
				configObject.Object, &configmapName,
			)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapName).To(Equal(randomName))

			// Check that the CA has been added to the configmap:
			configmapObject := corev1.ConfigMap{}
			configmapKey := clnt.ObjectKey{
				Namespace: "openshift-config",
				Name:      randomName,
			}
			err = client.Get(ctx, configmapKey, &configmapObject)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapObject.Data).To(
				HaveKeyWithValue("my.registry.com", "my-ca"),
			)
		})

		It("Adds CA to existing configmap", func() {
			// Create the configmap:
			configmapObject := &corev1.ConfigMap{
				ObjectMeta: metav1.ObjectMeta{
					Namespace:    "openshift-config",
					GenerateName: "your-",
				},
				Data: map[string]string{
					"your.registry.com": "your-ca",
				},
			}
			err := client.Create(ctx, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := client.Delete(ctx, configmapObject)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Update the image config:
			configObject := &unstructured.Unstructured{}
			configObject.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "config.openshift.io",
				Version: "v1",
				Kind:    "Image",
			})
			configKey := clnt.ObjectKey{
				Name: randomName,
			}
			err = client.Get(ctx, configKey, configObject)
			Expect(err).ToNot(HaveOccurred())
			configUpdate := configObject.DeepCopy()
			err = mergo.MapWithOverwrite(&configUpdate.Object, map[string]any{
				"spec": map[string]any{
					"additionalTrustedCA": map[string]any{
						"name": configmapObject.Name,
					},
				},
			})
			Expect(err).ToNot(HaveOccurred())
			err = client.Patch(ctx, configUpdate, clnt.MergeFrom(configObject))
			Expect(err).ToNot(HaveOccurred())

			// Add the registry:
			err = registryTool.AddTrustedRegistry(ctx, "my.registry.com", []byte("my-ca"))
			Expect(err).ToNot(HaveOccurred())

			// Check that the image configuration hasn't changed:
			err = client.Get(ctx, configKey, configObject)
			Expect(err).ToNot(HaveOccurred())
			var configmapName string
			err = jqTool.Query(
				`.spec.additionalTrustedCA.name`,
				configObject, &configmapName,
			)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapName).To(Equal(configmapObject.Name))

			// Check that the new CA has been added to the configmap and that the
			// existing one has been preserved:
			configmapKey := clnt.ObjectKeyFromObject(configmapObject)
			err = client.Get(ctx, configmapKey, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapObject.Data).To(
				HaveKeyWithValue("my.registry.com", "my-ca"),
			)
			Expect(configmapObject.Data).To(
				HaveKeyWithValue("your.registry.com", "your-ca"),
			)
		})

		It("Replaces existing CA", func() {
			// Create the configmap:
			configmapObject := &corev1.ConfigMap{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: "openshift-config",
					Name:      randomName,
				},
				Data: map[string]string{
					"my.registry.com": "my-old-ca",
				},
			}
			err := client.Create(ctx, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := client.Delete(ctx, configmapObject)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Update the image config:
			configObject := &unstructured.Unstructured{}
			configObject.SetGroupVersionKind(schema.GroupVersionKind{
				Group:   "config.openshift.io",
				Version: "v1",
				Kind:    "Image",
			})
			configKey := clnt.ObjectKey{
				Name: randomName,
			}
			err = client.Get(ctx, configKey, configObject)
			Expect(err).ToNot(HaveOccurred())
			configUpdate := configObject.DeepCopy()
			err = mergo.MapWithOverwrite(&configUpdate.Object, map[string]any{
				"spec": map[string]any{
					"additionalTrustedCA": map[string]any{
						"name": configmapObject.Name,
					},
				},
			})
			Expect(err).ToNot(HaveOccurred())
			err = client.Patch(ctx, configUpdate, clnt.MergeFrom(configObject))
			Expect(err).ToNot(HaveOccurred())

			// Add the registry, but with a different CA certificate:
			err = registryTool.AddTrustedRegistry(ctx, "my.registry.com", []byte("my-new-ca"))
			Expect(err).ToNot(HaveOccurred())

			// Check that the CA has been replaced:
			configmapKey := clnt.ObjectKeyFromObject(configmapObject)
			err = client.Get(ctx, configmapKey, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapObject.Data).To(
				HaveKeyWithValue("my.registry.com", "my-new-ca"),
			)
		})

		It("Generates configmap key with two dots when port explicitly set", func() {
			// Add the registry:
			err := registryTool.AddTrustedRegistry(ctx, "my.registry.com:5000", []byte("my-ca"))
			Expect(err).ToNot(HaveOccurred())

			// Check that the CA has been added with the right key:
			configmapObject := &corev1.ConfigMap{}
			configmapKey := clnt.ObjectKey{
				Namespace: "openshift-config",
				Name:      randomName,
			}
			err = client.Get(ctx, configmapKey, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			Expect(configmapObject.Data).To(
				HaveKeyWithValue("my.registry.com..5000", "my-ca"),
			)
		})

		It("Fetches CA from server if not explicitly passed", func() {
			// Create the server:
			server := NewTLSServer()
			defer func() {
				server.Close()
			}()

			// Add the registry:
			err := registryTool.AddTrustedRegistry(ctx, server.Addr(), nil)
			Expect(err).ToNot(HaveOccurred())

			// Check that the CA has been added:
			configmapObject := &corev1.ConfigMap{}
			configmapKey := clnt.ObjectKey{
				Namespace: "openshift-config",
				Name:      randomName,
			}
			err = client.Get(ctx, configmapKey, configmapObject)
			Expect(err).ToNot(HaveOccurred())
			serverHost, serverPort, err := net.SplitHostPort(server.Addr())
			Expect(err).ToNot(HaveOccurred())
			serverKey := fmt.Sprintf("%s..%s", serverHost, serverPort)
			Expect(configmapObject.Data).To(HaveKey(serverKey))

			// Check that the CA can be used to connect to the server:
			serverCA := []byte(configmapObject.Data[serverKey])
			caPool := x509.NewCertPool()
			ok := caPool.AppendCertsFromPEM(serverCA)
			Expect(ok).To(BeTrue())
			conn, err := tls.Dial(
				"tcp",
				server.Addr(),
				&tls.Config{
					RootCAs: caPool,
				},
			)
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := conn.Close()
				Expect(err).ToNot(HaveOccurred())
			}()
		})
	})
})
