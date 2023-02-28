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

type Cluster struct {
	API             API
	DNS             DNS
	ImageSet        string
	Ingress         Ingress
	Name            string
	Nodes           []*Node
	PullSecret      []byte
	SNO             bool
	SSH             SSH
	TPM             bool
	ClusterNetworks []*ClusterNetwork
	MachineNetworks []*MachineNetwork
	ServiceNetworks []*ServiceNetwork
	Kubeconfig      []byte
	Registry        Registry
}

// ContorlPlaneNodes returns an slice containing only the control plane nodes of the cluster.
func (c *Cluster) ControlPlaneNodes() []*Node {
	var nodes []*Node
	for _, node := range c.Nodes {
		if node.Kind == NodeKindControlPlane {
			nodes = append(nodes, node)
		}
	}
	return nodes
}

// WorkerNodes returns an slice containing only the workr nodes of the cluster.
func (c *Cluster) WorkerNodes() []*Node {
	var nodes []*Node
	for _, node := range c.Nodes {
		if node.Kind == NodeKindWorker {
			nodes = append(nodes, node)
		}
	}
	return nodes
}

// LookupNode returns an node with the given name, or nil if there is no such node.
func (c *Cluster) LookupNode(name string) *Node {
	for _, node := range c.Nodes {
		if node.Name == name {
			return node
		}
	}
	return nil
}

// NodeNames returns a slice containing the names of the nodes.
func (c *Cluster) NodeNames() []string {
	names := make([]string, len(c.Nodes))
	for i, node := range c.Nodes {
		names[i] = node.Name
	}
	return names
}
