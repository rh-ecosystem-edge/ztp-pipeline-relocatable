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

package jq

import (
	"math"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Tool", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without a logger", func() {
		// Create the template:
		tool, err := NewTool().Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(tool).To(BeNil())
	})

	It("Accepts primitive input", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		var x int
		err = tool.Query(`.`, 42, &x)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Accepts struct input", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		type Point struct {
			X int `json:"x"`
			Y int `json:"y"`
		}
		p := &Point{
			X: 42,
			Y: 24,
		}
		var x int
		err = tool.Query(`.x`, p, &x)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Accepts map input", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		m := map[string]int{
			"x": 42,
			"y": 24,
		}
		var x int
		err = tool.Query(`.x`, m, &x)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Accepts slice input", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		s := []int{42, 24}
		var x int
		err = tool.Query(`.[0]`, s, &x)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Gets all values if output is slice", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		s := []int{42, 24}
		var t []int
		err = tool.Query(`.[]`, s, &t)
		Expect(err).ToNot(HaveOccurred())
		Expect(t).To(ConsistOf(42, 24))
	})

	It("Gets first value if there is only one and output is not slice", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		s := []int{42}
		var x int
		err = tool.Query(`.[]`, s, &x)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Gets first value if there is only one and output is slice", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it accepts the input:
		s := []int{42}
		var t []int
		err = tool.Query(`.[]`, s, &t)
		Expect(err).ToNot(HaveOccurred())
		Expect(t).To(ConsistOf(42))
	})

	It("Fails if there are multiple results and output isn't slice", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it fails:
		s := []int{42, 24}
		var x int
		err = tool.Query(`.[]`, s, &x)
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("cannot"))
		Expect(msg).To(ContainSubstring("unmarshal"))
		Expect(msg).To(ContainSubstring("int"))
	})

	It("Fails if output is not compatible with input", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it fails:
		var x int
		err = tool.Query(`.`, "mytext", &x)
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("cannot"))
		Expect(msg).To(ContainSubstring("unmarshal"))
		Expect(msg).To(ContainSubstring("int"))
	})

	It("Rejects output that isn't a pointer", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it rejects the ouptut:
		var x int
		err = tool.Query(`.`, 42, x)
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("pointer"))
		Expect(msg).To(ContainSubstring("int"))
	})

	It("Can read from a string", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it can read from a string:
		var x int
		err = tool.QueryString(
			`.x`,
			`{
				"x": 42,
				"y": 24
			}`,
			&x,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Can read from an array of bytes", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it can read from an array of bytes:
		var x int
		err = tool.QueryBytes(
			`.x`,
			[]byte(`{
				"x": 42,
				"y": 24
			}`),
			&x,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(x).To(Equal(42))
	})

	It("Accepts struct output", func() {
		// Create the instance:
		tool, err := NewTool().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Check that it writes into a struct option:
		type Point struct {
			X int `json:"x"`
			Y int `json:"y"`
		}
		var p Point
		err = tool.QueryString(
			`{
				"x": .x,
				"y": .y
			}`,
			`{
				"x": 42,
				"y": 24
			}`,
			&p,
		)
		Expect(err).ToNot(HaveOccurred())
		Expect(p.X).To(Equal(42))
		Expect(p.Y).To(Equal(24))
	})
})
