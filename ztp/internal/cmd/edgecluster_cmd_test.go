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
	"os"
	"path/filepath"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	edgeclustercmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/edgecluster"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("'edgecluster' command", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetV(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Generates the expected objects for a simple SNO cluster", func() {
		// Create a temporary configuration file:
		tmp, _ := TmpFS(
			"config.yaml",
			Dedent(`
				edgeclusters:
				- my-sno:
				    master0:
				      ignore_ifaces: eno1 eno2
				      nic_ext_dhcp: eno4
				      mac_ext_dhcp: f8:1a:0e:f8:6a:f2
				      bmc_url: http://192.168.122.1/my-bmc
				      bmc_user: my-user
				      bmc_pass: my-pass
				      root_disk: /dev/sda
			`),
			"pull.json",
			Dedent(`{
				"auths": {
					"cloud.openshift.com": {
						"auth": "bXktdXNlcjpteS1wYXNz",
						"email": "mary@example.com"
					}
				}
			}`),
		)
		defer func() {
			err := os.RemoveAll(tmp)
			Expect(err).ToNot(HaveOccurred())
		}()

		// Run the command:
		tool, err := internal.NewTool().
			SetLogger(logger).
			AddArgs("oc-ztp", "edgecluster").
			AddCommand(edgeclustercmd.Cobra).
			SetEnv(map[string]string{
				"EDGECLUSTERS_FILE": filepath.Join(tmp, "config.yaml"),
				"PULL_SECRET":       filepath.Join(tmp, "pull.json"),
				"CLUSTERIMAGESET":   "my-image",
			}).
			SetIn(&bytes.Buffer{}).
			SetOut(GinkgoWriter).
			SetErr(GinkgoWriter).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run()
		Expect(err).ToNot(HaveOccurred())
	})
})
