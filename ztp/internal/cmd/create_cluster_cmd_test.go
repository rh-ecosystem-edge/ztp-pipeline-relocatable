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
	"os"
	"path/filepath"

	ignitionconfig "github.com/coreos/ignition/v2/config"
	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/decorators"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	createcmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/create"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Create cluster command", func() {
	var (
		ctx    context.Context
		logger logr.Logger
	)

	BeforeEach(func() {
		var err error

		// Create the context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	Context("Simple SNO cluster", Ordered, func() {
		var (
			tmp    string
			env    map[string]string
			client clnt.WithWatch
		)

		BeforeAll(func() {
			// Create a temporary directory containing the configuration files:
			tmp, _ = TmpFS(
				"config.yaml",
				Dedent(`
					config:
					  OC_OCP_VERSION: '4.11.20'
					  OC_ACM_VERSION: '2.6'
					  OC_ODF_VERSION: '4.11'
					edgeclusters:
					- edgecluster0-cluster:
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
				"pull.json",
				Dedent(`{
					"auths": {
						"cloud.openshift.com": {
							"auth": "bXktdXNlcjpteS1wYXNz",
							"email": "mary@my-domain.com"
						}
					}
				}`),
			)

			// Prepare the environment variables:
			env = map[string]string{
				"EDGECLUSTERS_FILE": filepath.Join(tmp, "config.yaml"),
				"CLUSTERIMAGESET":   "my-image",
			}

			// Run the command:
			tool, err := internal.NewTool().
				SetLogger(logger).
				AddArgs("ztp", "create", "cluster", "--wait=0").
				AddCommand(createcmd.Cobra).
				SetEnv(env).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())

			// Create the API client:
			client, err = internal.NewClient().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		AfterAll(func() {
			// Delete the temporary directory:
			err := os.RemoveAll(tmp)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the namespace", func() {
			object := &corev1.Namespace{}
			key := clnt.ObjectKey{
				Name: "edgecluster0-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the pull secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "pull-secret-edgecluster-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the manifests override configmap", func() {
			object := &corev1.ConfigMap{}
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster-manifests-override",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the agent cluster install", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.AgentClusterIntallGVK)
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the cluster deployment", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ClusterDeploymentGVK)
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the managed cluster", func() {
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.ManagedClusterGVK)
			key := clnt.ObjectKey{
				Name: "edgecluster0-cluster",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the infrastructure environment", func() {
			By("Creating the object")
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.InfraEnvGKV)
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster",
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
				Namespace: "edgecluster0-cluster",
				Name:      "ztpfw-edgecluster0-cluster-master-master0",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the BMC secret", func() {
			object := &corev1.Secret{}
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "ztpfw-edgecluster0-cluster-master-master0-bmc-secret",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates the bare metal host", func() {
			By("Creating the object")
			object := &unstructured.Unstructured{}
			object.SetGroupVersionKind(internal.BareMetalHostGVK)
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "ztpfw-edgecluster0-cluster-master-master0",
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
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster-keypair",
			}
			err := client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Creates missing object", func() {
			// Delete one of the objects:
			object := &corev1.Secret{
				ObjectMeta: metav1.ObjectMeta{
					Namespace: "edgecluster0-cluster",
					Name:      "edgecluster0-cluster-keypair",
				},
			}
			err := client.Delete(ctx, object)
			Expect(err).ToNot(HaveOccurred())

			// Run the command again:
			tool, err := internal.NewTool().
				SetLogger(logger).
				AddArgs("ztp", "create", "cluster", "--wait=0").
				AddCommand(createcmd.Cobra).
				SetEnv(env).
				SetIn(&bytes.Buffer{}).
				SetOut(GinkgoWriter).
				SetErr(GinkgoWriter).
				Build()
			Expect(err).ToNot(HaveOccurred())
			err = tool.Run(ctx)
			Expect(err).ToNot(HaveOccurred())

			// Check that the object has been created:
			key := clnt.ObjectKey{
				Namespace: "edgecluster0-cluster",
				Name:      "edgecluster0-cluster-keypair",
			}
			err = client.Get(ctx, key, object)
			Expect(err).ToNot(HaveOccurred())
		})
	})
})
