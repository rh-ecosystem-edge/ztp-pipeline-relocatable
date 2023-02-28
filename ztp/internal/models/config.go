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

type Config struct {
	Properties map[string]string
	Clusters   []*Cluster
}

// LookupCluster returns the cluser with the given name, or nil if no such cluster exists.
func (c *Config) LookupCluster(name string) *Cluster {
	for _, cluster := range c.Clusters {
		if cluster.Name == name {
			return cluster
		}
	}
	return nil
}

// ClusterNames returns a slice containing the names of the cluster.
func (c *Config) ClusterNames() []string {
	names := make([]string, len(c.Clusters))
	for i, cluster := range c.Clusters {
		names[i] = cluster.Name
	}
	return names
}
