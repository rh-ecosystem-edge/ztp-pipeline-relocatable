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

package internal

import (
	"bytes"
	"io"

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
)

var _ = Describe("Tool", func() {
	It("Can't be created without at least one argument", func() {
		tool, err := NewTool().
			In(&bytes.Buffer{}).
			Out(io.Discard).
			Err(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("binary"))
		Expect(msg).To(ContainSubstring("required"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard input stream", func() {
		tool, err := NewTool().
			Args("ztp").
			Out(io.Discard).
			Err(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("input"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard output stream", func() {
		tool, err := NewTool().
			Args("ztp").
			In(&bytes.Buffer{}).
			Err(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("output"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard error stream", func() {
		tool, err := NewTool().
			Args("ztp").
			In(&bytes.Buffer{}).
			Out(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("error"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})
})
