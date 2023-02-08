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
	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Config", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Loads cluster with single node", func() {
		By("Load configuration")
		config, err := NewConfigLoader().
			SetLogger(logger).
			SetSource(Dedent(`
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
			`)).
			Load()
		Expect(err).ToNot(HaveOccurred())

		By("Verify properties")
		Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_VERSION", "4.11.20"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ACM_VERSION", "2.6"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ODF_VERSION", "4.11"))

		By("Verify cluster")
		Expect(config.Clusters).To(HaveLen(1))
		cluster := config.Clusters[0]
		Expect(cluster.Name).To(Equal("edgecluster0-cluster"))
		Expect(cluster.TPM).To(BeFalse())

		By("Verify node")
		Expect(cluster.Nodes).To(HaveLen(1))
		node := cluster.Nodes[0]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master0"))
		Expect(node.ExternalNIC.Name).To(Equal("enp1s0"))
		Expect(node.ExternalNIC.MAC).To(Equal("63:ed:8b:f1:15:4c"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/d5405874-a05e-44bd-a6e1-f7105d6ed932"))
		Expect(node.BMC.User).To(Equal("user0"))
		Expect(node.BMC.Pass).To(Equal("pass0"))
		Expect(node.RootDisk).To(Equal("/dev/vda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/vdb"))
	})

	It("Loads cluster with multiple nodes", func() {
		By("Load configuration")
		config, err := NewConfigLoader().
			SetLogger(logger).
			SetSource(Dedent(`
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
				      mac_ext_dhcp: "df:2e:74:9e:2a:87"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/0487a8a0-bf51-460e-8ecd-729349f95125"
				      bmc_user: "user0"
				      bmc_pass: "pass0"
				      root_disk: /dev/vda
				      storage_disk:
				        - /dev/vdb
				    master1:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "dd:c5:f6:18:8f:ac"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/e3563c0a-59ca-4af6-90e5-04b655921e08"
				      bmc_user: "user1"
				      bmc_pass: "pass1"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
				    master2:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "83:8e:3f:38:bc:87"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/48f72d2a-aea8-4cc4-9c1e-b92d35ad35ad"
				      bmc_user: "user2"
				      bmc_pass: "pass2"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
				    worker0:
				      nic_ext_dhcp: enp1s0
				      mac_ext_dhcp: "e6:19:4d:a8:82:58"
				      bmc_url: "redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/b12af704-a17f-4e4f-8b1a-d4771ebc5bd4"
				      bmc_user: "user3"
				      bmc_pass: "pass3"
				      root_disk: /dev/vda
				      storage_disk:
				      - /dev/vdb
			`)).
			Load()
		Expect(err).ToNot(HaveOccurred())

		By("Verify properties")
		Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_VERSION", "4.11.20"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ACM_VERSION", "2.6"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ODF_VERSION", "4.11"))

		By("Verify cluster")
		Expect(config.Clusters).To(HaveLen(1))
		cluster := config.Clusters[0]
		Expect(cluster.Name).To(Equal("edgecluster0-cluster"))
		Expect(cluster.TPM).To(BeFalse())
		Expect(cluster.Nodes).To(HaveLen(4))

		By("Verify first node")
		node := cluster.Nodes[0]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master0"))
		Expect(node.ExternalNIC.Name).To(Equal("enp1s0"))
		Expect(node.ExternalNIC.MAC).To(Equal("df:2e:74:9e:2a:87"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/0487a8a0-bf51-460e-8ecd-729349f95125"))
		Expect(node.BMC.User).To(Equal("user0"))
		Expect(node.BMC.Pass).To(Equal("pass0"))
		Expect(node.RootDisk).To(Equal("/dev/vda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/vdb"))

		By("Verify second node")
		node = cluster.Nodes[1]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master1"))
		Expect(node.ExternalNIC.Name).To(Equal("enp1s0"))
		Expect(node.ExternalNIC.MAC).To(Equal("dd:c5:f6:18:8f:ac"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/e3563c0a-59ca-4af6-90e5-04b655921e08"))
		Expect(node.BMC.User).To(Equal("user1"))
		Expect(node.BMC.Pass).To(Equal("pass1"))
		Expect(node.RootDisk).To(Equal("/dev/vda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/vdb"))

		By("Verify third node")
		node = cluster.Nodes[2]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master2"))
		Expect(node.ExternalNIC.Name).To(Equal("enp1s0"))
		Expect(node.ExternalNIC.MAC).To(Equal("83:8e:3f:38:bc:87"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/48f72d2a-aea8-4cc4-9c1e-b92d35ad35ad"))
		Expect(node.BMC.User).To(Equal("user2"))
		Expect(node.BMC.Pass).To(Equal("pass2"))
		Expect(node.RootDisk).To(Equal("/dev/vda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/vdb"))

		By("Verify fourth node")
		node = cluster.Nodes[3]
		Expect(node.Kind).To(Equal(models.NodeKindWorker))
		Expect(node.Name).To(Equal("worker0"))
		Expect(node.ExternalNIC.Name).To(Equal("enp1s0"))
		Expect(node.ExternalNIC.MAC).To(Equal("e6:19:4d:a8:82:58"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/b12af704-a17f-4e4f-8b1a-d4771ebc5bd4"))
		Expect(node.BMC.User).To(Equal("user3"))
		Expect(node.BMC.Pass).To(Equal("pass3"))
		Expect(node.RootDisk).To(Equal("/dev/vda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/vdb"))
	})

	It("Loads cluster with multiple network interface cards", func() {
		By("Load configuration")
		config, err := NewConfigLoader().
			SetLogger(logger).
			SetSource(Dedent(`
				config:
				  OC_OCP_VERSION: '4.11.20'
				  OC_ACM_VERSION: '2.6'
				  OC_ODF_VERSION: '4.11'
				edgeclusters:
				- spk-factory-0:
				    config:
				      tpm: true
				    master0:
				      nic_ext_dhcp: enp0s3
				      nic_int_static: enp0s4
				      mac_int_static: 8d:5c:ec:5c:db:20
				      mac_ext_dhcp: 1b:22:67:9e:5d:61
				      bmc_url: redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/3cfeb445-248d-46d3-bc86-15969ebd5245
				      bmc_user: admin
				      bmc_pass: password
				      root_disk: "/dev/sda"
				      storage_disk:
				      - /dev/sdb
				      - /dev/sdc
				      - /dev/sdd
				    master1:
				      nic_ext_dhcp: enp0s3
				      nic_int_static: enp0s4
				      mac_int_static: f9:21:50:8f:9d:68
				      mac_ext_dhcp: 84:e6:4d:94:07:a4
				      bmc_url: redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/5aa364f7-151c-4de9-8902-5958299e97d3
				      bmc_user: admin
				      bmc_pass: password
				      root_disk: "/dev/sda"
				      storage_disk:
				      - /dev/sdb
				      - /dev/sdc
				      - /dev/sdd
				    master2:
				      nic_ext_dhcp: enp0s3
				      nic_int_static: enp0s4
				      mac_int_static: e7:d3:33:60:e8:d0
				      mac_ext_dhcp: af:73:ab:5b:90:31
				      bmc_url: redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/c2183827-1f60-473e-a5ee-5f587619a0b0
				      bmc_user: admin
				      bmc_pass: password
				      root_disk: "/dev/sda"
				      storage_disk:
				      - /dev/sdb
				      - /dev/sdc
				      - /dev/sdd
				    worker0:
				      nic_ext_dhcp: enp0s3
				      nic_int_static: enp0s4
				      mac_int_static: f5:92:66:41:f1:38
				      mac_ext_dhcp: ab:1c:50:fc:f7:8a
				      bmc_url: redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/9e0a017a-00d1-495f-a4c1-4edd5f5ec78f
				      bmc_user: admin
				      bmc_pass: password
				      root_disk: "/dev/sda"
				      storage_disk:
				      - /dev/sdb
				      - /dev/sdc
				      - /dev/sdd
			`)).
			Load()
		Expect(err).ToNot(HaveOccurred())

		By("Verify properties")
		Expect(config.Properties).To(HaveKeyWithValue("OC_OCP_VERSION", "4.11.20"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ACM_VERSION", "2.6"))
		Expect(config.Properties).To(HaveKeyWithValue("OC_ODF_VERSION", "4.11"))

		By("Verify cluster")
		Expect(config.Clusters).To(HaveLen(1))
		cluster := config.Clusters[0]
		Expect(cluster.Name).To(Equal("spk-factory-0"))
		Expect(cluster.TPM).To(BeTrue())
		Expect(cluster.Nodes).To(HaveLen(4))

		By("Verify first node")
		node := cluster.Nodes[0]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master0"))
		Expect(node.ExternalNIC.Name).To(Equal("enp0s3"))
		Expect(node.ExternalNIC.MAC).To(Equal("1b:22:67:9e:5d:61"))
		Expect(node.InternalNIC.Name).To(Equal("enp0s4"))
		Expect(node.InternalNIC.MAC).To(Equal("8d:5c:ec:5c:db:20"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/3cfeb445-248d-46d3-bc86-15969ebd5245"))
		Expect(node.BMC.User).To(Equal("admin"))
		Expect(node.BMC.Pass).To(Equal("password"))
		Expect(node.RootDisk).To(Equal("/dev/sda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/sdb", "/dev/sdc", "/dev/sdd"))

		By("Verify second node")
		node = cluster.Nodes[1]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master1"))
		Expect(node.ExternalNIC.Name).To(Equal("enp0s3"))
		Expect(node.ExternalNIC.MAC).To(Equal("84:e6:4d:94:07:a4"))
		Expect(node.InternalNIC.Name).To(Equal("enp0s4"))
		Expect(node.InternalNIC.MAC).To(Equal("f9:21:50:8f:9d:68"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/5aa364f7-151c-4de9-8902-5958299e97d3"))
		Expect(node.BMC.User).To(Equal("admin"))
		Expect(node.BMC.Pass).To(Equal("password"))
		Expect(node.RootDisk).To(Equal("/dev/sda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/sdb", "/dev/sdc", "/dev/sdd"))

		By("Verify third node")
		node = cluster.Nodes[2]
		Expect(node.Kind).To(Equal(models.NodeKindControlPlane))
		Expect(node.Name).To(Equal("master2"))
		Expect(node.ExternalNIC.Name).To(Equal("enp0s3"))
		Expect(node.ExternalNIC.MAC).To(Equal("af:73:ab:5b:90:31"))
		Expect(node.InternalNIC.Name).To(Equal("enp0s4"))
		Expect(node.InternalNIC.MAC).To(Equal("e7:d3:33:60:e8:d0"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/c2183827-1f60-473e-a5ee-5f587619a0b0"))
		Expect(node.BMC.User).To(Equal("admin"))
		Expect(node.BMC.Pass).To(Equal("password"))
		Expect(node.RootDisk).To(Equal("/dev/sda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/sdb", "/dev/sdc", "/dev/sdd"))

		By("Verify fourth node")
		node = cluster.Nodes[3]
		Expect(node.Kind).To(Equal(models.NodeKindWorker))
		Expect(node.Name).To(Equal("worker0"))
		Expect(node.ExternalNIC.Name).To(Equal("enp0s3"))
		Expect(node.ExternalNIC.MAC).To(Equal("ab:1c:50:fc:f7:8a"))
		Expect(node.InternalNIC.Name).To(Equal("enp0s4"))
		Expect(node.InternalNIC.MAC).To(Equal("f5:92:66:41:f1:38"))
		Expect(node.BMC.URL).To(Equal("redfish-virtualmedia://192.168.123.1:8000/redfish/v1/Systems/9e0a017a-00d1-495f-a4c1-4edd5f5ec78f"))
		Expect(node.BMC.User).To(Equal("admin"))
		Expect(node.BMC.Pass).To(Equal("password"))
		Expect(node.RootDisk).To(Equal("/dev/sda"))
		Expect(node.StorageDisks).To(ConsistOf("/dev/sdb", "/dev/sdc", "/dev/sdd"))
	})

	It("Loads multiple clusters", func() {
		// Load the configuration:
		config, err := NewConfigLoader().
			SetLogger(logger).
			SetSource(Dedent(`
				edgeclusters:
				- edgecluster0-cluster: {}
				- edgecluster1-cluster: {}
				- edgecluster2-cluster: {}
			`)).
			Load()
		Expect(err).ToNot(HaveOccurred())

		// Check the number and names of the clusters:
		Expect(config.Clusters).To(HaveLen(3))
		Expect(config.Clusters[0].Name).To(Equal("edgecluster0-cluster"))
		Expect(config.Clusters[1].Name).To(Equal("edgecluster1-cluster"))
		Expect(config.Clusters[2].Name).To(Equal("edgecluster2-cluster"))
	})
})
