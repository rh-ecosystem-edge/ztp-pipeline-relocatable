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
	"sync/atomic"
	"time"

	ignitionconfig "github.com/coreos/ignition/v2/config"
	"github.com/go-logr/logr"
	"github.com/google/uuid"
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
)

var _ = Describe("Create cluster command", Ordered, func() {
	var (
		ctx    context.Context
		logger logr.Logger
		client *internal.Client
	)

	BeforeAll(func() {
		var err error

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
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
	})

	Context("Simple SNO cluster", Ordered, func() {
		var (
			name   string
			config string
		)

		BeforeAll(func() {
			// Prepare the configuration:
			name = fmt.Sprintf("my-%s", uuid.NewString())
			config = Template(
				Dedent(`
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
		})

		AfterAll(func() {
			// Run the command to delete the cluster:
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "delete", "cluster",
					"--config", config,
				).
				AddCommand(deletecmd.Cobra).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the namespace", func() {
			object := &corev1.Namespace{}
			key := clnt.ObjectKey{
				Name: name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the pull secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      "pull-secret-edgecluster-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the manifests override configmap", func() {
			object := &corev1.ConfigMap{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("%s-manifests-override", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the agent cluster install", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.AgentClusterIntallGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the cluster deployment", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ClusterDeploymentGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the managed cluster", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ManagedClusterGVK)
			key := clnt.ObjectKey{
				Name: name,
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the infrastructure environment", func() {
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

		It("Creates the `nmstate` configuration environment", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.NMStateConfigGVK)
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("ztpfw-%s-master-0", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the BMC secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("ztpfw-%s-master-0-bmc-secret", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the bare metal host", func() {
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

		It("Creates the SSH secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: name,
				Name:      fmt.Sprintf("%s-keypair", name),
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates missing object", func() {
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
		// Create a temporary directory containing the configuration files:
		name := fmt.Sprintf("my-%s", uuid.NewString())
		config := Template(
			Dedent(`
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

		// Remember to delete the cluster when done:
		defer func() {
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "delete", "cluster",
					"--config", config,
				).
				AddCommand(deletecmd.Cobra).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())
		}()

		// Run the command to create the cluster in a separate goroutine:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		finished := &atomic.Bool{}
		go func() {
			defer GinkgoRecover()
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "create", "cluster",
					"--config", config,
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
			finished.Store(true)
		}()

		// Wait till the bare metal host exists, and then set the state to provisioned:
		bmhObject := &unstructured.Unstructured{}
		bmhObject.SetGroupVersionKind(internal.BareMetalHostGVK)
		bmhKey := clnt.ObjectKey{
			Namespace: name,
			Name:      fmt.Sprintf("ztpfw-%s-master-0", name),
		}
		Eventually(func() error {
			return client.Get(ctx, bmhKey, bmhObject)
		}, time.Minute).Should(Succeed())
		bmhUpdate := bmhObject.DeepCopy()
		bmhUpdate.Object["status"] = map[string]any{
			"provisioning": map[string]any{
				"ID":    uuid.NewString(),
				"state": "provisioned",
			},
			"errorMessage":      "my-error",
			"hardwareProfile":   "my-profile",
			"operationalStatus": "OK",
			"poweredOn":         true,
		}
		err := client.Status().Patch(ctx, bmhUpdate, clnt.MergeFrom(bmhObject))
		Expect(err).ToNot(HaveOccurred())

		// Wait till the agent cluster install exists and set it status to completed:
		aciObject := &unstructured.Unstructured{}
		aciObject.SetGroupVersionKind(internal.AgentClusterIntallGVK)
		aciKey := clnt.ObjectKey{
			Namespace: name,
			Name:      name,
		}
		Eventually(func() error {
			return client.Get(ctx, aciKey, aciObject)
		}, time.Minute).Should(Succeed())
		aciUpdate := aciObject.DeepCopy()
		aciUpdate.Object["status"] = map[string]any{
			"conditions": []any{
				map[string]any{
					"type":   "Completed",
					"status": "True",
				},
			},
		}
		err = client.Status().Patch(ctx, aciUpdate, clnt.MergeFrom(aciObject))
		Expect(err).ToNot(HaveOccurred())

		// Wait till the tool finishes:
		Eventually(finished.Load, time.Minute).Should(BeTrue())

		// Check that the tool has written the message that indicates that the cluster
		// completed the installation:
		Expect(buffer.String()).To(ContainSubstring("Cluster '%s' is installed", name))
	})

	It("Writes the states as the installation progresses", func() {
		// Create a temporary directory containing the configuration files:
		name := fmt.Sprintf("my-%s", uuid.NewString())
		config := Template(
			Dedent(`
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

		// Remember to delete the cluster when done:
		defer func() {
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "delete", "cluster",
					"--config", config,
				).
				AddCommand(deletecmd.Cobra).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())
		}()

		// Run the command to create the cluster in a separate goroutine:
		buffer := &bytes.Buffer{}
		multi := io.MultiWriter(buffer, GinkgoWriter)
		finished := &atomic.Bool{}
		go func() {
			defer GinkgoRecover()
			tool, err := internal.NewTool().
				SetLogger(logger).
				SetArgs(
					"ztp", "create", "cluster",
					"--config", config,
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
			finished.Store(true)
		}()

		// Wait till the bare metal host exists, and then set the state to provisioned:
		bmhObject := &unstructured.Unstructured{}
		bmhObject.SetGroupVersionKind(internal.BareMetalHostGVK)
		bmhKey := clnt.ObjectKey{
			Namespace: name,
			Name:      fmt.Sprintf("ztpfw-%s-master-0", name),
		}
		Eventually(func() error {
			return client.Get(ctx, bmhKey, bmhObject)
		}, time.Minute).Should(Succeed())
		bmhUpdate := bmhObject.DeepCopy()
		bmhUpdate.Object["status"] = map[string]any{
			"provisioning": map[string]any{
				"ID":    uuid.NewString(),
				"state": "provisioned",
			},
			"errorMessage":      "my-error",
			"hardwareProfile":   "my-profile",
			"operationalStatus": "OK",
			"poweredOn":         true,
		}
		err := client.Status().Patch(ctx, bmhUpdate, clnt.MergeFrom(bmhObject))
		Expect(err).ToNot(HaveOccurred())

		// Wait till the agent cluster install exists:
		aciObject := &unstructured.Unstructured{}
		aciObject.SetGroupVersionKind(internal.AgentClusterIntallGVK)
		aciKey := clnt.ObjectKey{
			Namespace: name,
			Name:      name,
		}
		Eventually(func() error {
			return client.Get(ctx, aciKey, aciObject)
		}, time.Minute).Should(Succeed())

		// Wait a bit before the next update, otherwise the API server will coalesce the
		// events and the tool will only see the second update:
		time.Sleep(time.Second)

		// Update the state to `my-state`:
		aciUpdate := aciObject.DeepCopy()
		aciUpdate.Object["status"] = map[string]any{
			"debugInfo": map[string]any{
				"state": "my-state",
			},
		}
		err = client.Status().Patch(ctx, aciUpdate, clnt.MergeFrom(aciObject))
		Expect(err).ToNot(HaveOccurred())

		// Update the status to completed:
		aciUpdate = aciObject.DeepCopy()
		aciUpdate.Object["status"] = map[string]any{
			"conditions": []any{
				map[string]any{
					"type":   "Completed",
					"status": "True",
				},
			},
		}
		err = client.Status().Patch(ctx, aciUpdate, clnt.MergeFrom(aciObject))
		Expect(err).ToNot(HaveOccurred())

		// Wait till the tool finishes:
		Eventually(finished.Load, time.Minute).Should(BeTrue())

		// Check that the tool has written the message that indicate the changes of state:
		Expect(buffer.String()).To(ContainSubstring("Cluster '%s' moved to state 'my-state'", name))
	})
})
