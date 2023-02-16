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
	. "github.com/onsi/gomega"
)

var _ = Describe("Clusters", func() {
	It("Filters nodes according to kind", func() {
		cluster := &Cluster{
			Nodes: []*Node{
				{
					Kind: NodeKindControlPlane,
					Name: "master0",
				},
				{
					Kind: NodeKindControlPlane,
					Name: "master1",
				},
				{
					Kind: NodeKindControlPlane,
					Name: "master2",
				},
				{
					Kind: NodeKindWorker,
					Name: "worker0",
				},
				{
					Kind: NodeKindWorker,
					Name: "worker1",
				},
			},
		}
		controlPlaneNodes := cluster.ControlPlaneNodes()
		Expect(controlPlaneNodes).To(HaveLen(3))
		Expect(controlPlaneNodes[0].Kind).To(Equal(NodeKindControlPlane))
		Expect(controlPlaneNodes[1].Kind).To(Equal(NodeKindControlPlane))
		Expect(controlPlaneNodes[2].Kind).To(Equal(NodeKindControlPlane))
		workerNodes := cluster.WorkerNodes()
		Expect(workerNodes).To(HaveLen(2))
		Expect(workerNodes[0].Kind).To(Equal(NodeKindWorker))
		Expect(workerNodes[1].Kind).To(Equal(NodeKindWorker))
	})
})
