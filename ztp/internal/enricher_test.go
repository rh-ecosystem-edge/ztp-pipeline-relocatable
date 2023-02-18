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
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"net/http"
	"os"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/decorators"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/ghttp"
	. "github.com/onsi/gomega/ghttp"
	"golang.org/x/crypto/ssh"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Enricher", Ordered, func() {
	var (
		ctx      context.Context
		logger   logr.Logger
		client   *Client
		registry *ghttp.Server
	)

	BeforeAll(func() {
		var err error

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Get the Kubernetes API client. Note that we create this only once and share it
		// for all the tests because the initial discovery is quite expensive and noisy, and
		// we don't really need to have a separate client for each test.
		client, err = NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create a fake registry server. This will not serve any request, it will only be
		// used to fetch the CA certificates.
		registry = ghttp.NewTLSServer()
	})

	AfterAll(func() {
		var err error

		// Stop the client:
		if client != nil {
			err = client.Close()
			Expect(err).ToNot(HaveOccurred())
		}

		// Stop the registry server:
		if registry != nil {
			registry.Close()
		}
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
			enricher   *Enricher
			properties map[string]string
		)

		BeforeEach(func() {
			var err error

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Prepare the default properties. These are convenient in most tests
			// because otherwise the enricher will try to fetch the `release.txt` file
			// to determine the values, and that may fail due to network issues.
			properties = map[string]string{
				"OC_OCP_VERSION":   "4.10.38",
				"OC_OCP_TAG":       "4.10.38-x86_64",
				"OC_RHCOS_RELEASE": "410.84.202210130022-0",
				"clusterimageset":  "openshift-v4.10.38",
			}

			// Create the enricher:
			enricher, err = NewEnricher().
				SetLogger(logger).
				SetClient(client).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		BeforeEach(func() {
			// Create a context:
			ctx = context.Background()

		})

		It("Sets the SNO flag to true when there is only one control plane node", func() {
			// Create the config:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name:       name,
					PullSecret: custom,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					DNS: models.DNS{
						Domain: "example.net",
					},
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			properties["OC_OCP_TAG"] = "my-tag"
			config := &models.Config{
				Properties: properties,
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_TAG", "my-tag"))
		})

		It("Calculates the OCP tag if not set", func() {
			delete(properties, "OC_OCP_TAG")
			config := &models.Config{
				Properties: properties,
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_TAG", "4.10.38-x86_64"))
		})

		It("Doesn't change the RHCOS release if already set", func() {
			properties["OC_RHCOS_RELEASE"] = "my-release"
			config := &models.Config{
				Properties: properties,
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("OC_RHCOS_RELEASE", "my-release"))
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
			delete(properties, "OC_RHCOS_RELEASE")
			properties["OC_OCP_MIRROR"] = server.URL()
			config := &models.Config{
				Properties: properties,
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
			delete(properties, "OC_RHCOS_RELEASE")
			properties["OC_OCP_MIRROR"] = server.URL()
			config := &models.Config{
				Properties: properties,
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
			delete(properties, "OC_RHCOS_RELEASE")
			properties["OC_OCP_MIRROR"] = server.URL()
			config := &models.Config{
				Properties: properties,
			}

			// Check that it fails:
			err := enricher.Enrich(ctx, config)
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("find RHCOS release"))
			Expect(msg).To(ContainSubstring("release.txt"))
		})

		It("Sets the hardcoded cluster CIDR", func() {
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
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

		It("Doesn't change the SSH keys if already set", func() {
			// Generate the key pair:
			rsaKey, err := rsa.GenerateKey(rand.Reader, 4096)
			Expect(err).ToNot(HaveOccurred())
			sshKey, err := ssh.NewPublicKey(&rsaKey.PublicKey)
			Expect(err).ToNot(HaveOccurred())
			publicKey := ssh.MarshalAuthorizedKey(sshKey)
			privateKey := pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PRIVATE KEY",
				Bytes: x509.MarshalPKCS1PrivateKey(rsaKey),
			})

			// Create the cluster with the SSH keys already set:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					SSH: models.SSH{
						PublicKey:  publicKey,
						PrivateKey: privateKey,
					},
				}},
			}

			// Verify that they aren't replaced:
			err = enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.SSH.PublicKey).To(Equal(publicKey))
			Expect(cluster.SSH.PrivateKey).To(Equal(privateKey))
		})

		It("Takes the keys from the secret if it exists", func() {
			// Generate the key pair:
			rsaKey, err := rsa.GenerateKey(rand.Reader, 4096)
			Expect(err).ToNot(HaveOccurred())
			sshKey, err := ssh.NewPublicKey(&rsaKey.PublicKey)
			Expect(err).ToNot(HaveOccurred())
			publicKey := ssh.MarshalAuthorizedKey(sshKey)
			privateKey := pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PRIVATE KEY",
				Bytes: x509.MarshalPKCS1PrivateKey(rsaKey),
			})

			// Create the namespace:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			namespace := &corev1.Namespace{
				ObjectMeta: metav1.ObjectMeta{
					Name: name,
				},
			}
			err = client.Create(ctx, namespace)
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := client.Delete(ctx, namespace)
				Expect(err).ToNot(HaveOccurred())
			}()

			// Create the secret:
			secret := &corev1.Secret{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: name,
					Name:      fmt.Sprintf("%s-keypair", name),
				},
				Data: map[string][]byte{
					"id_rsa.pub": publicKey,
					"id_rsa.key": privateKey,
				},
			}
			err = client.Create(ctx, secret)
			Expect(err).ToNot(HaveOccurred())

			// Enrich the cluster:
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
				}},
			}
			err = enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Verify that the keys are the ones from the secret:
			cluster := config.Clusters[0]
			Expect(cluster.SSH.PublicKey).To(Equal(publicKey))
			Expect(cluster.SSH.PrivateKey).To(Equal(privateKey))
		})

		It("Takes external IP addresses from agents", func() {
			// Prepare the agents:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			data := map[string]any{
				"Name":    name,
				"Indexes": []int{0, 1, 2},
			}
			tmp, fsys := TmpFS(
				"objects.yaml",
				Dedent(`
					---
					apiVersion: v1
					kind: Namespace
					metadata:
					  name: {{ .Name }}
					{{ range .Indexes }}
					---
					apiVersion: agent-install.openshift.io/v1beta1
					kind: Agent
					metadata:
					  namespace: {{ $.Name }}
					  name: master{{ . }}
					status:
					  inventory:
					    interfaces:
					    - flags: []
					      macAddress: a2:87:c3:6d:61:d{{ . }}
					      ipV4Addresses:
					      - 192.168.150.10{{ . }}/24
					      ipV6Addresses: []
					{{ end }}
				`),
			)
			defer os.RemoveAll(tmp)
			applier, err := NewApplier().
				SetLogger(logger).
				SetClient(client).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := applier.Delete(ctx, data)
				Expect(err).ToNot(HaveOccurred())
			}()
			err = applier.Apply(ctx, data)
			Expect(err).ToNot(HaveOccurred())

			// Enrich the cluster:
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
					Nodes: []*models.Node{
						{
							Name: "master0",
							ExternalNIC: models.NIC{
								MAC: "a2:87:c3:6d:61:d0",
							},
						},
						{
							Name: "master1",
							ExternalNIC: models.NIC{
								MAC: "a2:87:c3:6d:61:d1",
							},
						},
						{
							Name: "master2",
							ExternalNIC: models.NIC{
								MAC: "a2:87:c3:6d:61:d2",
							},
						},
					},
				}},
			}
			err = enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Verify external IP addresses:
			cluster := config.Clusters[0]
			Expect(cluster.Nodes[0].ExternalNIC.IP.String()).To(Equal("192.168.150.100"))
			Expect(cluster.Nodes[1].ExternalNIC.IP.String()).To(Equal("192.168.150.101"))
			Expect(cluster.Nodes[2].ExternalNIC.IP.String()).To(Equal("192.168.150.102"))
		})

		It("Takes kubeconfig from secret", func() {
			// Prepare the secret:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			data := map[string]any{
				"Name": name,
			}
			tmp, fsys := TmpFS(
				"objects.yaml",
				Dedent(`
					---
					apiVersion: v1
					kind: Namespace
					metadata:
					  name: {{ .Name }}
					---
					apiVersion: v1
					kind: Secret
					metadata:
					  namespace: {{ .Name }}
					  name: {{ .Name }}-admin-kubeconfig
					data:
					  kubeconfig: bXkta3ViZWNvbmZpZw==
				`),
			)
			defer os.RemoveAll(tmp)
			applier, err := NewApplier().
				SetLogger(logger).
				SetClient(client).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())
			defer func() {
				err := applier.Delete(ctx, data)
				Expect(err).ToNot(HaveOccurred())
			}()
			err = applier.Apply(ctx, data)
			Expect(err).ToNot(HaveOccurred())

			// Enrich the cluster:
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
				}},
			}
			err = enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Verify external IP addresses:
			cluster := config.Clusters[0]
			Expect(string(cluster.Kubeconfig)).To(Equal("my-kubeconfig"))
		})

		It("Doesn't change kubeconfig if already set", func() {
			// Enrich the cluster:
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name:       name,
					Kubeconfig: []byte("your-kubeconfig"),
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Verify external IP addresses:
			cluster := config.Clusters[0]
			Expect(string(cluster.Kubeconfig)).To(Equal("your-kubeconfig"))
		})

		It("Calculates the default cluster image set", func() {
			delete(properties, "clusterimageset")
			config := &models.Config{
				Properties: properties,
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("clusterimageset", "openshift-v4.10.38"))
		})

		It("Doesn't change the cluster image set if already set", func() {
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.ImageSet).To(Equal("openshift-v4.10.38"))
		})

		It("Doesn't change the cluster image set if already set", func() {
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name:     name,
					ImageSet: "my-image-set",
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.ImageSet).To(Equal("my-image-set"))
		})

		It("Doesn't change the registry if already set", func() {
			properties["REGISTRY"] = registry.Addr()
			config := &models.Config{
				Properties: properties,
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			Expect(config.Properties).To(HaveKeyWithValue("REGISTRY", registry.Addr()))
		})

		It("Copies non default registry to the clusters", func() {
			properties["REGISTRY"] = registry.Addr()
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())
			cluster := config.Clusters[0]
			Expect(cluster.Registry.URL).To(Equal(registry.Addr()))
		})

		It("Fetches the registry CA certificates", func() {
			// Create the cluster with the custom registry:
			properties["REGISTRY"] = registry.Addr()
			name := fmt.Sprintf("my-%s", uuid.NewString())
			config := &models.Config{
				Properties: properties,
				Clusters: []*models.Cluster{{
					Name: name,
				}},
			}
			err := enricher.Enrich(ctx, config)
			Expect(err).ToNot(HaveOccurred())

			// Verify that the certificates can be used to connect to the regisry:
			cluster := config.Clusters[0]
			Expect(cluster.Registry.CA).ToNot(BeEmpty())
			pool := x509.NewCertPool()
			ok := pool.AppendCertsFromPEM(cluster.Registry.CA)
			Expect(ok).To(BeTrue())
			conn, err := tls.Dial("tcp", registry.Addr(), &tls.Config{
				RootCAs: pool,
			})
			Expect(err).ToNot(HaveOccurred())
			defer conn.Close()
		})
	})
})
