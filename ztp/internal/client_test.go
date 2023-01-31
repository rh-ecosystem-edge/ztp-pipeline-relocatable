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
	"encoding/json"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Client", func() {
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
			SetV(1).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without a logger", func() {
		client, err := NewClient().
			SetKubeconfig(kubeconfig).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(client).To(BeNil())
	})

	It("Can retrieve information from the cluster", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			SetKubeconfig(kubeconfig).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(client).ToNot(BeNil())

		// Retrieve the list of pods:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Gets the configuration from the KUBECONFIG passed in the env", func() {
		// Create a temporary directory for the configuration file:
		dir, _ := TmpFS("my.config", kubeconfig)
		defer func() {
			err := os.RemoveAll(dir)
			Expect(err).ToNot(HaveOccurred())
		}()

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			SetEnv(map[string]string{
				"KUBECONFIG": filepath.Join(dir, "my.config"),
			}).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(client).ToNot(BeNil())

		// Check that it can connect to the cluster. Note that we use the `example` CRD that
		// we create only in the testing cluster to make sure that we are connecting to that
		// cluster and not to any other that may be avaiable via the `~/.kube/config` file
		// or via the real `KUBECONFIG` environment variable.
		object := &unstructured.Unstructured{}
		object.SetGroupVersionKind(schema.GroupVersionKind{
			Group:   "example.com",
			Version: "v1",
			Kind:    "Example",
		})
		key := clnt.ObjectKey{
			Name: "example",
		}
		err = client.Get(ctx, key, object)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Writes to the log the details of the request and response", func() {
		// Create a logger that writes to a memory buffer and with the v-level 3 enabled, as
		// that is the level used for the detail of HTTP requests and responses:
		buffer := &bytes.Buffer{}
		logger, err := logging.NewLogger().
			SetWriter(buffer).
			SetV(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			SetKubeconfig(kubeconfig).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Send a first request to force the client to do all the initial requests that it
		// does to retrieve metadata, we are not interested in that.
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())

		// Clear the log buffer and send the request again so that we can analyze the result
		// of that particular request:
		buffer.Reset()
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
		lines := strings.Split(buffer.String(), "\n")

		// There should be at least three messages: sending the request header, received the
		// response header and received the response body. Note that there may be more if
		// the response body is fragmented.
		Expect(len(lines)).To(BeNumerically(">=", 3))
		type Message struct {
			Msg    string `json:"msg"`
			Method string `json:"method"`
			URL    string `json:"url"`
			Code   int    `json:"code"`
			N      int    `json:"n"`
		}
		var message Message

		// The first message should contain the details of the request header:
		err = json.Unmarshal([]byte(lines[0]), &message)
		Expect(err).ToNot(HaveOccurred())
		Expect(message.Msg).To(Equal("Sending request header"))
		Expect(message.Method).To(Equal("GET"))
		Expect(message.URL).To(MatchRegexp("^https://.*/api/v1/pods$"))

		// The second message should contain the details of the response header:
		err = json.Unmarshal([]byte(lines[1]), &message)
		Expect(err).ToNot(HaveOccurred())
		Expect(message.Msg).To(Equal("Received response header"))
		Expect(message.Code).To(Equal(200))

		// The third message should contain the details of the response body:
		err = json.Unmarshal([]byte(lines[2]), &message)
		Expect(err).ToNot(HaveOccurred())
		Expect(message.Msg).To(Equal("Received response body"))
		Expect(message.Code).To(Equal(200))
		Expect(message.N).To(BeNumerically(">", 0))
	})
})
