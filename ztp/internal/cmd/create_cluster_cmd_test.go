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

package cmd

import (
	"bytes"
	"context"
	"fmt"
	"io"

	ignitionconfig "github.com/coreos/ignition/v2/config"
	"github.com/go-logr/logr"
	"github.com/google/uuid"
	"github.com/imdario/mergo"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/decorators"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	createcmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/create"
	deletecmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/delete"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/text"
)

var _ = Describe("Create cluster command", Ordered, func() {
	var (
		ctx     context.Context
		name    string
		config  string
		logger  logr.Logger
		client  *internal.Client
		manager *Manager
		dns     *DNSServer
	)

	BeforeAll(func() {
		var err error

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(1).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err = internal.NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterAll(func() {
		var err error

		// Stop the client:
		if client != nil {
			err = client.Close()
			Expect(err).ToNot(HaveOccurred())
		}
	})

	BeforeEach(func() {
		// Create the context:
		ctx = context.Background()

		// Generate a random cluster name:
		name = fmt.Sprintf("my-%s", uuid.NewString())

		// Prepare the DNS server:
		dns = NewDNSServer()
		DeferCleanup(dns.Close)
		dns.AddZone("my-domain.com")
		dns.AddHost(fmt.Sprintf("api.%s.my-domain.com", name), "192.168.150.100")
		dns.AddHost(fmt.Sprintf("apps.%s.my-domain.com", name), "192.168.150.101")

		// Create the controller manager:
		manager = NewManager().
			SetLogger(logger).
			AddGVK(internal.BareMetalHostGVK).
			AddGVK(internal.AgentClusterInstallGVK).
			Build()

		// Add a reconciler that moves bare metal hosts to the provisioned state:
		manager.AddReconciler(
			internal.BareMetalHostGVK,
			func(ctx context.Context, object *unstructured.Unstructured) {
				update := object.DeepCopy()
				err := mergo.Map(&update.Object, map[string]any{
					"status": map[string]any{
						"provisioning": map[string]any{
							"ID":    uuid.NewString(),
							"state": "provisioned",
						},
						"errorMessage":      "my-error",
						"hardwareProfile":   "my-profile",
						"operationalStatus": "OK",
						"poweredOn":         true,
					},
				})
				Expect(err).ToNot(HaveOccurred())
				err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
				Expect(err).ToNot(HaveOccurred())
			},
		)
	})

	AfterEach(func() {
		// Delete the cluster:
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "delete", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
			).
			AddCommand(deletecmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(GinkgoWriter).
			SetErr(GinkgoWriter).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).ToNot(HaveOccurred())

		// Stop the controller manager:
		manager.Close()
	})

	It("Creates SNO cluster", func() {
		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command:
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "0",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(GinkgoWriter).
			SetErr(GinkgoWriter).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).ToNot(HaveOccurred())

		By("Creating the namespace", func() {
			object := &corev1.Namespace{}
			key := clnt.ObjectKey{
				Name: name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the pull secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      "pull-secret-edgecluster-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the manifests override configmap", func() {
			object := &corev1.ConfigMap{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("%s-manifests-override", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the agent cluster install", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.AgentClusterInstallGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the cluster deployment", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ClusterDeploymentGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the managed cluster", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ManagedClusterGVK)
			key := clnt.ObjectKey{
				Name: name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the infrastructure environment", func() {
			By("Creating the object")
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.InfraEnvGKV)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())

			By("Generating valid ignition configuration")
			ignition, ok, err := unstructured.NestedString(
				object.Object,
				"spec",
				"ignitionConfigOverride",
			)
			Expect(err).ToNot(HaveOccurred())
			Expect(ok).To(BeTrue())
			_, report, err := ignitionconfig.Parse([]byte(ignition))
			Expect(err).ToNot(HaveOccurred())
			Expect(report.Entries).To(BeEmpty())
		})

		By("Creating the `nmstate` configuration", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.NMStateConfigGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("ztpfw-%s-master-0", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the BMC secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("ztpfw-%s-master-0-bmc-secret", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating the bare metal host", func() {
			By("Creating the object")
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.BareMetalHostGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("ztpfw-%s-master-0", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())

			By("Generating valid ignition configuration")
			annotations := object.GetAnnotations()
			Expect(annotations).ToNot(BeNil())
			ignition, ok := annotations["bmac.agent-install.openshift.io/ignition-config-overrides"]
			Expect(ok).To(BeTrue())
			_, report, err := ignitionconfig.Parse([]byte(ignition))
			Expect(err).ToNot(HaveOccurred())
			Expect(report.Entries).To(BeEmpty())
		})

		By("Creating the SSH secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("%s-keypair", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		By("Creating missing object", func() {
			// Delete one of the objects:
			object := &corev1.Secret{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: name,
					Name:      fmt.Sprintf("%s-keypair", name),
				},
			}
			err := client.Delete(ctx, object)
			Expect(err).ToNot(HaveOccurred())

			// Run the command again:
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "create", "cluster",
					"--config", config,
					"--resolver", dns.Address(),
					"--wait", "0",
				).
				AddCommand(createcmd.Cobra).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())

			// Check that the object has been created:
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("%s-keypair", name),
			}
			err = client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})
	})

	It("Waits till the cluster is ready", func() {
		// Add a reconciler that marks agent cluster installations as completed:
		manager.AddReconciler(
			internal.AgentClusterInstallGVK,
			func(ctx context.Context, object *unstructured.Unstructured) {
				update := object.DeepCopy()
				err := mergo.Map(&update.Object, map[string]any{
					"status": map[string]any{
						"conditions": []any{
							map[string]any{
								"type":   "Completed",
								"status": "True",
							},
						},
					},
				})
				Expect(err).ToNot(HaveOccurred())
				err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
				Expect(err).ToNot(HaveOccurred())
			},
		)

		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command to create the cluster:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "1m",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(multi).
			SetErr(multi).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).ToNot(HaveOccurred())

		// Check that the tool has written the message that indicates that the cluster
		// completed the installation:
		Expect(buffer.String()).To(ContainSubstring(
			"Installation of cluster '%s' succeeded",
			name,
		))
	})

	It("Writes the states as the installation progresses", func() {
		// Add a reconciler that moves the cluster to a custom state and marks it
		// as completed:
		manager.AddReconciler(
			internal.AgentClusterInstallGVK,
			func(ctx context.Context, object *unstructured.Unstructured) {
				update := object.DeepCopy()
				err := mergo.Map(&update.Object, map[string]any{
					"status": map[string]any{
						"debugInfo": map[string]any{
							"state": "my-state",
						},
						"conditions": []any{
							map[string]any{
								"type":   "Completed",
								"status": "True",
							},
						},
					},
				})
				Expect(err).ToNot(HaveOccurred())
				err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
				Expect(err).ToNot(HaveOccurred())
			},
		)

		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command to create the cluster:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "1m",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(multi).
			SetErr(multi).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).ToNot(HaveOccurred())

		// Check that the tool has written the message that indicate the changes of state:
		Expect(buffer.String()).To(ContainSubstring(
			"Cluster '%s' moved to state 'my-state'",
			name,
		))
	})

	It("Fails when the 'Failed' condition is true", func() {
		// Add a reconciler that marks the cluster as failed:
		manager.AddReconciler(
			internal.AgentClusterInstallGVK,
			func(ctx context.Context, object *unstructured.Unstructured) {
				update := object.DeepCopy()
				err := mergo.Map(&update.Object, map[string]any{
					"status": map[string]any{
						"debugInfo": map[string]any{
							"state": "my-state",
						},
						"conditions": []any{
							map[string]any{
								"type":   "Failed",
								"status": "True",
							},
						},
					},
				})
				Expect(err).ToNot(HaveOccurred())
				err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
				Expect(err).ToNot(HaveOccurred())
			},
		)

		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command to create the cluster:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "1m",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(multi).
			SetErr(multi).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).To(HaveOccurred())

		// Check that the tool has written the message that indicates that the cluster
		// installation failed:
		Expect(buffer.String()).To(ContainSubstring(
			"Installation of cluster '%s' failed",
			name,
		))
	})

	It("Fails when the cluster moves to the 'error' state", func() {
		// Add a reconciler that marks the cluster as failed:
		manager.AddReconciler(
			internal.AgentClusterInstallGVK,
			func(ctx context.Context, object *unstructured.Unstructured) {
				update := object.DeepCopy()
				err := mergo.Map(&update.Object, map[string]any{
					"status": map[string]any{
						"debugInfo": map[string]any{
							"state": "error",
						},
					},
				})
				Expect(err).ToNot(HaveOccurred())
				err = client.Status().Patch(ctx, update, clnt.MergeFrom(object))
				Expect(err).ToNot(HaveOccurred())
			},
		)

		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command to create the cluster:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "1m",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(multi).
			SetErr(multi).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).To(HaveOccurred())

		// Check that the tool has written the message that indicates that the cluster
		// installation failed:
		Expect(buffer.String()).To(ContainSubstring(
			"Installation of cluster '%s' failed because it moved to the 'error' state",
			name,
		))
	})

	It("Fails when the timeout expires", func() {
		// Prepare the configuration:
		config = Template(
			text.Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- {{ .Name }}:
				    config:
				      tpm: false
				    contrib:
				      gpu-operator:
				        version: "v1.10.1"
				    master0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "63:ed:8b:f1:15:4c"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`),
			"Name", name,
		)

		// Run the command to create the:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		tool, err := internal.NewTool().
			SetLogger(logger).
			SetArgs(
				"ztp", "create", "cluster",
				"--config", config,
				"--resolver", dns.Address(),
				"--wait", "1s",
			).
			AddCommand(createcmd.Cobra).
			SetIn(&bytes.Buffer{}).
			SetOut(multi).
			SetErr(multi).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).To(HaveOccurred())

		// Check that the tool has written the message that indicates that the cluster
		// installation failed:
		Expect(buffer.String()).To(ContainSubstring(
			"Clusters aren't ready after waiting",
		))
	})
})
