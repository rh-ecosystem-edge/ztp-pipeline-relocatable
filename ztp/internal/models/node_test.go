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

package models

import (
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Nodes", func() {
	DescribeTable(
		"Extracts index from node name",
		func(node *Node, expected string) {
			actual := node.Index()
			Expect(actual).To(Equal(expected))
		},
		Entry(
			"Control plane node one digit",
			&Node{
				Name: "master0",
			},
			"0",
		),
		Entry(
			"Control plane node two digits",
			&Node{
				Name: "master12",
			},
			"12",
		),
		Entry(
			"Control plane node three digits",
			&Node{
				Name: "master123",
			},
			"123",
		),
		Entry(
			"Worker node one digit",
			&Node{
				Name: "worker0",
			},
			"0",
		),
		Entry(
			"Worker node two digits",
			&Node{
				Name: "worker12",
			},
			"12",
		),
		Entry(
			"Worker node three digits",
			&Node{
				Name: "worker123",
			},
			"123",
		),
		Entry(
			"Unknown node kind",
			&Node{
				Name: "junk123",
			},
			"123",
		),
		Entry(
			"No index",
			&Node{
				Name: "worker",
			},
			"",
		),
	)
})
