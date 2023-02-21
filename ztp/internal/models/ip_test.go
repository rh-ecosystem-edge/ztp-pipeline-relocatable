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
	"net"

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("IP", func() {
	DescribeTable(
		"Parses string correctly",
		func(s string, expected *IP) {
			actual, err := ParseIP(s)
			Expect(err).ToNot(HaveOccurred())
			Expect(actual).To(Equal(expected))
		},
		Entry(
			"Class A",
			"10.0.0.123/8",
			&IP{
				Address: net.ParseIP("10.0.0.123"),
				Prefix:  8,
			},
		),
		Entry(
			"Class B",
			"172.16.0.123/16",
			&IP{
				Address: net.ParseIP("172.16.0.123"),
				Prefix:  16,
			},
		),
		Entry(
			"Class C",
			"192.168.122.123/24",
			&IP{
				Address: net.ParseIP("192.168.122.123"),
				Prefix:  24,
			},
		),
		Entry(
			"CIDR 26",
			"192.168.122.123/26",
			&IP{
				Address: net.ParseIP("192.168.122.123"),
				Prefix:  26,
			},
		),
	)

	DescribeTable(
		"Generates string correctly",
		func(ip *IP, expected string) {
			actual := ip.String()
			Expect(actual).To(Equal(expected))
		},
		Entry(
			"Class A",
			&IP{
				Address: net.ParseIP("10.0.0.123"),
				Prefix:  8,
			},
			"10.0.0.123/8",
		),
		Entry(
			"Class B",
			&IP{
				Address: net.ParseIP("172.16.0.123"),
				Prefix:  16,
			},
			"172.16.0.123/16",
		),
		Entry(
			"Class C",
			&IP{
				Address: net.ParseIP("192.168.122.123"),
				Prefix:  24,
			},
			"192.168.122.123/24",
		),
		Entry(
			"CIDR 26",
			&IP{
				Address: net.ParseIP("192.168.122.123"),
				Prefix:  26,
			},
			"192.168.122.123/26",
		),
	)
})
