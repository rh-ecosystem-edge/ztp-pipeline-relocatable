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
	"context"
	"io"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	"github.com/spf13/cobra"
	"k8s.io/klog/v2"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Tool", func() {
	var (
		ctx    context.Context
		logger logr.Logger
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create a logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without at least one argument", func() {
		tool, err := NewTool().
			SetLogger(logger).
			SetIn(&bytes.Buffer{}).
			SetOut(io.Discard).
			SetErr(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("binary"))
		Expect(msg).To(ContainSubstring("required"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard input stream", func() {
		tool, err := NewTool().
			SetLogger(logger).
			AddArgs("ztp").
			SetOut(io.Discard).
			SetErr(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("input"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard output stream", func() {
		tool, err := NewTool().
			SetLogger(logger).
			AddArgs("ztp").
			SetIn(&bytes.Buffer{}).
			SetErr(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("output"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Can't be created standard error stream", func() {
		tool, err := NewTool().
			SetLogger(logger).
			AddArgs("ztp").
			SetIn(&bytes.Buffer{}).
			SetOut(io.Discard).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("error"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Configures 'klog' to use the logger", func() {
		// Execute the tool with a 'nop' command that writes a log message using the 'klog'
		// package:
		buffer := &bytes.Buffer{}
		tee := io.MultiWriter(buffer, GinkgoWriter)
		logger, err := logging.NewLogger().
			SetWriter(tee).
			SetLevel(2).
			Build()
		Expect(err).ToNot(HaveOccurred())
		tool, err := NewTool().
			SetLogger(logger).
			SetIn(&bytes.Buffer{}).
			SetOut(io.Discard).
			SetErr(io.Discard).
			AddCommand(func() *cobra.Command {
				return &cobra.Command{
					Use: "nop",
					Run: func(cmd *cobra.Command, args []string) {
						klog.Info("My message")
					},
				}
			}).
			SetArgs("ztp", "nop").
			Build()
		Expect(err).ToNot(HaveOccurred())
		err = tool.Run(ctx)
		Expect(err).ToNot(HaveOccurred())

		// Verify that the message is written to our log:
		Expect(buffer.String()).To(ContainSubstring("My message"))
	})
})
