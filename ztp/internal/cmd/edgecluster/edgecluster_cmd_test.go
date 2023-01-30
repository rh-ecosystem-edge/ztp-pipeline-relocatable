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

package edgecluster

import (
	"bytes"
	"testing"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

func TestCmd(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Edge cluster command")
}

var _ = Describe("Edge cluster command", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetV(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	// TODO: This test is disabled because currently we don't have a Kubernetes API server
	// running in the tests environment.
	XIt("Prints the server version", func() {
		// Prepare buffers to capture the output:
		inBuffer := &bytes.Buffer{}
		outBuffer := &bytes.Buffer{}
		errBuffer := &bytes.Buffer{}

		// Run the command:
		tool, err := internal.NewTool().
			SetLogger(logger).
			AddArgs("oc-ztp", "edgecluster").
			AddCommand(Command).
			SetIn(inBuffer).
			SetOut(outBuffer).
			SetErr(errBuffer).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run()
		Expect(err).ToNot(HaveOccurred())

		// Check the otuput:
		outText := outBuffer.String()
		Expect(outText).To(ContainSubstring("Server version: 1.25.2"))
		errText := errBuffer.String()
		Expect(errText).To(BeEmpty())
	})
})
