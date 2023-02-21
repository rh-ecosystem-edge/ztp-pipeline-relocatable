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
	"regexp"
)

type NodeKind string

const (
	NodeKindControlPlane NodeKind = "ControlPlane"
	NodeKindWorker       NodeKind = "Worker"
)

type Node struct {
	Kind         NodeKind
	Name         string
	Hostname     string
	BMC          BMC
	RootDisk     string
	StorageDisks []string
	InternalNIC  *NIC
	InternalIP   *IP
	ExternalNIC  *NIC
	ExternalIP   *IP
	IgnoredNICs  []string
}

// Index extracts the index from the name of the node. For example, if the name is `worker123` then
// the index will be `123`. This is needed because currently some of our pipelines rely on node
// names having that index. This will be removed when those pipelines have been updatedd, so refrain
// from using it.
func (n *Node) Index() string {
	matches := nodeIndexRE.FindStringSubmatch(n.Name)
	if matches == nil {
		return ""
	}
	return matches[1]
}

// nodeIndexRE is the regular expression used to extract the numeric index from the name of the node.
var nodeIndexRE = regexp.MustCompile(`(\d+)$`)
