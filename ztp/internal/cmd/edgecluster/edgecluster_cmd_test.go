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

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
)

func TestCmd(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Version command")
}

var _ = Describe("Version command", func() {
	It("Prints the build commit", func() {
		// Prepare buffers to capture the output:
		inBuffer := &bytes.Buffer{}
		outBuffer := &bytes.Buffer{}
		errBuffer := &bytes.Buffer{}

		// Run the command:
		tool, err := internal.NewTool().
			Args("ztp", "version").
			Command(Command).
			In(inBuffer).
			Out(outBuffer).
			Err(errBuffer).
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run()
		Expect(err).ToNot(HaveOccurred())

		// Check the otuput. Note that we expect unknown commit and time because the test
		// binaries don't include this information.
		outText := outBuffer.String()
		Expect(outText).To(ContainSubstring("Build commit: unknown"))
		Expect(outText).To(ContainSubstring("Build time: unknown"))
		errText := errBuffer.String()
		Expect(errText).To(BeEmpty())
	})
})
