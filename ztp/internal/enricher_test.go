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
	"math"
	"os"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

var _ = Describe("Enricher", func() {
	var (
		ctx    context.Context
		logger logr.Logger
		client clnt.Client
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetV(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Get the Kubernetes API client:
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without a logger", func() {
		enricher, err := NewEnricher().
			SetClient(client).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(enricher).To(BeNil())
	})

	It("Can't be created without a Kubernetes API client", func() {
		enricher, err := NewEnricher().
			SetLogger(logger).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("client"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(enricher).To(BeNil())
	})

	Context("Already created", func() {
		var (
			defaultPullSecretData []byte
			defaultPullSecretFile string
			defaultImageSet       string
			enricher              *Enricher
		)

		BeforeEach(func() {
			var err error

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Create a temporary file containing the default pull secret:
			defaultPullSecretData = []byte(`{
				"auths": {
					"cloud.openshift.com": {
						"auth": "bXktdXNlcjpteS1wYXNz",
						"email": "mary@example.com"
					}
				}
			}`)
			defaultPullSecretStream, err := os.CreateTemp("", "*.test")
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := defaultPullSecretStream.Close()
				Expect(err).ToNot(HaveOccurred())
			}()
			_, err = defaultPullSecretStream.Write(defaultPullSecretData)
			Expect(err).ToNot(HaveOccurred())
			defaultPullSecretFile = defaultPullSecretStream.Name()

			// Prepare the default image set:
			defaultImageSet = "my-image-set"

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				SetEnv(map[string]string{
					"PULL_SECRET":     defaultPullSecretFile,
					"CLUSTERIMAGESET": defaultImageSet,
				}).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			// Delete the temporary files:
			err := os.Remove(defaultPullSecretFile)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Sets the SNO flag to true when there is only one control plane node", func() {
			// Create the cluster:
			cluster := &models.Cluster{
				Name: "my-cluster",
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(cluster.SNO).To(BeTrue())
		})

		It("Sets the SNO flag to false when there are three control plane nodes", func() {
			// Create the cluster:
			cluster := &models.Cluster{
				Name: "my-cluster",
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node-0",
					},
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node-1",
					},
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node-2",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(cluster.SNO).To(BeFalse())
		})

		It("Doesn't change the pull secret if already set", func() {
			// Prepare a pull secret different to the one in the environment:
			customPullSecretData := []byte(`{
				"auths": {
					"cloud.openshift.com": {
						"auth": "eW91ci11c2VyOnlvdXItcGFzcw==",
						"email": "joe@example.com"
					},
				}
			}`)

			// Create the cluster with that pull secret:
			cluster := &models.Cluster{
				Name:       "my-cluster",
				PullSecret: customPullSecretData,
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the pull secret hasn't changed:
			Expect(cluster.PullSecret).To(Equal(customPullSecretData))
		})

		It("Gets the pull secret from the environment variable", func() {
			// Create the cluster without a pull secret:
			cluster := &models.Cluster{
				Name: "my-cluster",
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the pull secret has been set:
			Expect(cluster.PullSecret).To(Equal(defaultPullSecretData))
		})

		It("Doesn't change the DNS domain if already set", func() {
			// Create the cluster:
			cluster := &models.Cluster{
				Name: "my-cluster",
				DNS: models.DNS{
					Domain: "example.net",
				},
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(cluster.DNS.Domain).To(Equal("example.net"))
		})

		It("Gets the DNS domain from the default ingress controller of the hub", func() {
			// Create the cluster:
			cluster := &models.Cluster{
				Name: "my-cluster",
				Nodes: []models.Node{
					{
						Kind: models.NodeKindControlPlane,
						Name: "my-node",
					},
				},
			}

			// Enrich the cluster:
			err := enricher.Enrich(ctx, cluster)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(cluster.DNS.Domain).To(Equal("example.com"))
		})
	})
})
