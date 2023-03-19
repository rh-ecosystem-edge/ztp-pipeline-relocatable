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

package environment

import (
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Environment", func() {
	It("Adds one variable", func() {
		env, err := New().
			SetVar("MY_VAR", "my-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf("MY_VAR=my-value"))
	})

	It("Adds two variables", func() {
		env, err := New().
			SetVar("MY_VAR", "my-value").
			SetVar("YOUR_VAR", "your-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-value",
			"YOUR_VAR=your-value",
		))
	})

	It("Adds multiple variables", func() {
		env, err := New().
			SetVars(map[string]any{
				"MY_VAR":   "my-value",
				"YOUR_VAR": "your-value",
			}).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-value",
			"YOUR_VAR=your-value",
		))
	})

	It("Adds one variable and multiple variables", func() {
		env, err := New().
			SetVars(map[string]any{
				"MY_VAR":   "my-value",
				"YOUR_VAR": "your-value",
			}).
			SetVar("HER_VAR", "her-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-value",
			"YOUR_VAR=your-value",
			"HER_VAR=her-value",
		))
	})

	It("Parses value from pair list", func() {
		env, err := New().
			SetEnv(
				"MY_VAR=my-value",
				"YOUR_VAR=your-value",
			).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-value",
			"YOUR_VAR=your-value",
		))
	})

	It("Replaces earlier value", func() {
		env, err := New().
			SetVar("MY_VAR", "my-old-value").
			SetVar("MY_VAR", "my-new-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-new-value",
		))
	})

	It("Doesn't replace later value", func() {
		env, err := New().
			SetVar("MY_VAR", "my-new-value").
			SetVar("MY_VAR", "my-old-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-old-value",
		))
	})

	It("Replaces value in pair list", func() {
		env, err := New().
			SetEnv("MY_VAR=my-value").
			SetVar("MY_VAR", "my-new-value").
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(env).To(ConsistOf(
			"MY_VAR=my-new-value",
		))
	})

	DescribeTable(
		"Succeeds for supports types",
		func(value any, expected string) {
			actual, err := New().
				SetVar("X", value).
				Build()
			Expect(err).ToNot(HaveOccurred())
			Expect(actual).To(ConsistOf("X=" + expected))
		},
		Entry("Nil", nil, ""),
		Entry("Boolean true", true, "true"),
		Entry("Boolean false", false, "false"),
		Entry("Int zero", 0, "0"),
		Entry("Int positive", 123, "123"),
		Entry("Int negative", -123, "-123"),
		Entry("Float positive", 1.23, "1.23"),
		Entry("Float negative", -1.23, "-1.23"),
		Entry("Stringer", Red, "red"),
	)

	DescribeTable(
		"Fails for unsupported types",
		func(value any, expected string) {
			_, err := New().
				SetVar("X", value).
				Build()
			Expect(err).To(HaveOccurred())
			msg := err.Error()
			Expect(msg).To(ContainSubstring("X"))
			Expect(msg).To(ContainSubstring("failed"))
			Expect(msg).To(ContainSubstring(expected))
		},
		Entry("Slice", []int{}, "[]int"),
		Entry("Map", map[int]int{}, "map[int]int"),
	)
})

// Color is a type used for the tests.
type Color int

const (
	Red Color = iota
	Green
	Blue
)

func (c Color) String() string {
	switch c {
	case Red:
		return "red"
	case Green:
		return "green"
	case Blue:
		return "blue"
	default:
		return "gray"
	}
}
