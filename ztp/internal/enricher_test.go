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
	"net/http"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/ghttp"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
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
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Get the Kubernetes API client:
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	Context("Creation", func() {
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
	})

	Context("Usage", func() {
		var (
			defaultImageSet string
			enricher        *Enricher
		)

		BeforeEach(func() {
			var err error

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Prepare the default image set:
			defaultImageSet = "my-image-set"

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				SetEnv(map[string]string{
					"CLUSTERIMAGESET": defaultImageSet,
				}).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		It("Sets the SNO flag to true when there is only one control plane node", func() {
			// Create the config:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(config.Clusters[0].SNO).To(BeTrue())
		})

		It("Sets the SNO flag to false when there are three control plane nodes", func() {
			// Create the config:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
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
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(config.Clusters[0].SNO).To(BeFalse())
		})

		It("Doesn't change the pull secret if already set", func() {
			// Prepare a pull secret different to the one in the environment:
			custom := []byte(`{
				"auths": {
					"cloud.openshift.com": {
						"auth": "eW91ci11c2VyOnlvdXItcGFzcw==",
						"email": "joe@my-domain.com"
					},
				}
			}`)

			// Create the config with that pull secret:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name:       "my-cluster",
					PullSecret: custom,
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the pull secret hasn't changed:
			Expect(config.Clusters[0].PullSecret).To(Equal(custom))
		})

		It("Gets the pull secret from the environment", func() {
			// Create the config without a pull secret:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the pull secret is the one from the environment:
			Expect(config.Clusters[0].PullSecret).To(MatchJSON(`{
				"auths": {
					"cloud.openshift.com": {
						"auth": "bXktdXNlcjpteS1wYXNz",
						"email": "mary@my-domain.com"
					}
				}
			}`))
		})

		It("Doesn't change the DNS domain if already set", func() {
			// Create the cluster:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
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
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(config.Clusters[0].DNS.Domain).To(Equal("example.net"))
		})

		It("Gets the DNS domain from the default ingress controller of the hub", func() {
			// Create the config:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}

			// Enrich the config:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Check that the flag has been set:
			Expect(config.Clusters[0].DNS.Domain).To(Equal("my-domain.com"))
		})

		It("Fails if the OCP version property isn't set", func() {
			config := &models.Config{}
			err := enricher.Enrich(ctx, config)
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("OC_OCP_VERSION"))
		})

		It("Doesn't change OCP tag if already set", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "my-tag",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_TAG", "my-tag"))
		})

		It("Calculates the OCP tag if not set", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_TAG", "4.10.38-x86_64"))
		})

		It("Doesn't change the RHCOS release if already set", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "my-release",
				},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_RHCOS_RELEASE", "my-release"))
		})

		It("Doesn't change the RHCOS release if already set", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "my-release",
				},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue(
				"OC_RHCOS_RELEASE", "my-release",
			))
		})

		It("Extracts the RHCOS release from the `release.txt` file", func() {
			// Prepare the mirror server:
			server := NewServer()
			defer server.Close()
			server.AppendHandlers(RespondWith(
				http.StatusOK,
				Dedent(`
					Component Versions:
					  kubernetes 1.23.12               
					  machine-os my-release Red Hat Enterprise Linux CoreOS
				`),
			))

			// Create the enricher:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION": "4.10.38",
					"OC_OCP_TAG":     "4.10.38-x86_64",
					"OC_OCP_MIRROR":  server.URL(),
				},
			}

			// Check that it gets the release returned by the server:
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue(
				"OC_RHCOS_RELEASE", "my-release",
			))
		})

		It("Fails if the mirror responds with an error", func() {
			// Prepare the mirror server:
			server := NewServer()
			defer server.Close()
			server.AppendHandlers(RespondWith(http.StatusNotFound, nil))

			// Create the enricher:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION": "4.10.38",
					"OC_OCP_TAG":     "4.10.38-x86_64",
					"OC_OCP_MIRROR":  server.URL(),
				},
			}

			// Check that it fails:
			err := enricher.Enrich(ctx, config)
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("release.txt"))
			Expect(msg).To(ContainSubstring(server.URL()))
			Expect(msg).To(ContainSubstring("404"))
		})

		It("Fails if the `release.txt` file doesn't contain the expected text", func() {
			// Prepare the mirror server:
			server := NewServer()
			defer server.Close()
			server.AppendHandlers(RespondWith(http.StatusOK, "junk"))

			// Create the enricher:
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION": "4.10.38",
					"OC_OCP_TAG":     "4.10.38-x86_64",
					"OC_OCP_MIRROR":  server.URL(),
				},
			}

			// Check that it fails:
			err := enricher.Enrich(ctx, config)
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("find RHCOS release"))
			Expect(msg).To(ContainSubstring("release.txt"))
		})

		It("Sets the hardcoded cluster CIDR", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Clusters[0].ClusterNetworks).To(HaveLen(1))
			Expect(config.Clusters[0].ClusterNetworks[0].CIDR.String()).To(Equal(
				"10.128.0.0/14",
			))
			Expect(config.Clusters[0].ClusterNetworks[0].HostPrefix).To(Equal(23))
		})

		It("Sets the hardcoded machine CIDR", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Clusters[0].MachineNetworks).To(HaveLen(1))
			Expect(config.Clusters[0].MachineNetworks[0].CIDR.String()).To(Equal(
				"192.168.7.0/24",
			))
		})

		It("Sets the hardcoded service CIDR", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-node",
						},
					},
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Clusters[0].ServiceNetworks).To(HaveLen(1))
			Expect(config.Clusters[0].ServiceNetworks[0].CIDR.String()).To(Equal(
				"172.30.0.0/16",
			))
		})

		It("Sets the hardcoded internal IP addresses for multiple nodes", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-master-0",
							InternalNIC: models.NIC{
								Name: "eth0",
								MAC:  "17:c0:34:9c:f7:52",
							},
							ExternalNIC: models.NIC{
								Name: "eth1",
								MAC:  "f6:aa:2c:d0:24:40",
							},
						},
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-master-1",
							InternalNIC: models.NIC{
								Name: "eth0",
								MAC:  "11:0f:8b:d9:ea:76",
							},
							ExternalNIC: models.NIC{
								Name: "eth1",
								MAC:  "9c:bf:cd:0f:6a:c4",
							},
						},
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-master-2",
							InternalNIC: models.NIC{
								Name: "eth0",
								MAC:  "8e:a2:8c:a7:06:d6",
							},
							ExternalNIC: models.NIC{
								Name: "eth1",
								MAC:  "24:23:0a:53:8a:16",
							},
						},
						{
							Kind: models.NodeKindWorker,
							Name: "my-worker-0",
							InternalNIC: models.NIC{
								Name: "eth0",
								MAC:  "f2:d3:c4:b7:ab:0a",
							},
							ExternalNIC: models.NIC{
								Name: "eth1",
								MAC:  "69:7e:09:78:33:45",
							},
						},
					},
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.Nodes[0].InternalNIC.IP.String()).To(Equal("192.168.7.10"))
			Expect(cluster.Nodes[0].InternalNIC.Prefix).To(Equal(24))
			Expect(cluster.Nodes[1].InternalNIC.IP.String()).To(Equal("192.168.7.11"))
			Expect(cluster.Nodes[1].InternalNIC.Prefix).To(Equal(24))
			Expect(cluster.Nodes[2].InternalNIC.IP.String()).To(Equal("192.168.7.12"))
			Expect(cluster.Nodes[2].InternalNIC.Prefix).To(Equal(24))
			Expect(cluster.Nodes[3].InternalNIC.IP.String()).To(Equal("192.168.7.13"))
			Expect(cluster.Nodes[3].InternalNIC.Prefix).To(Equal(24))
			Expect(cluster.API.VIP).To(Equal("192.168.7.242"))
			Expect(cluster.Ingress.VIP).To(Equal("192.168.7.243"))
		})

		It("Sets the hardcoded internal IP addresses for SNO", func() {
			config := &models.Config{
				Properties: map[string]string{
					"OC_OCP_VERSION":   "4.10.38",
					"OC_OCP_TAG":       "4.10.38-x86_64",
					"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				},
				Clusters: []models.Cluster{{
					Name: "my-cluster",
					Nodes: []models.Node{
						{
							Kind: models.NodeKindControlPlane,
							Name: "my-master-0",
							InternalNIC: models.NIC{
								Name: "eth0",
								MAC:  "17:c0:34:9c:f7:52",
							},
							ExternalNIC: models.NIC{
								Name: "eth1",
								MAC:  "f6:aa:2c:d0:24:40",
							},
						},
					},
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.Nodes[0].InternalNIC.IP.String()).To(Equal("192.168.7.10"))
			Expect(cluster.Nodes[0].InternalNIC.Prefix).To(Equal(24))
			Expect(cluster.API.VIP).To(BeEmpty())
			Expect(cluster.Ingress.VIP).To(BeEmpty())
		})
	})
})
