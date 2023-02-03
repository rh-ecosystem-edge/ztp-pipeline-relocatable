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

import "k8s.io/apimachinery/pkg/runtime/schema"

// This file contains constants for some GroupVersionKinds that are used frequently in the project.

var (
	AgentClusterIntallGVK = schema.GroupVersionKind{
		Group:   "extensions.hive.openshift.io",
		Version: "v1beta1",
		Kind:    "AgentClusterInstall",
	}
	AgentClusterIntallListGVK = listGVK(AgentClusterIntallGVK)

	BareMetalHostGVK = schema.GroupVersionKind{
		Group:   "metal3.io",
		Version: "v1alpha1",
		Kind:    "BareMetalHost",
	}
	BareMetalHostListGVK = listGVK(BareMetalHostGVK)

	ClusterDeploymentGVK = schema.GroupVersionKind{
		Group:   "hive.openshift.io",
		Version: "v1",
		Kind:    "ClusterDeployment",
	}
	ClusterDeploymentListGVK = listGVK(ClusterDeploymentGVK)

	CustomResourceDefinitionGVK = schema.GroupVersionKind{
		Group:   "apiextensions.k8s.io",
		Version: "v1",
		Kind:    "CustomResourceDefinition",
	}
	CustomResourceDefinitionListGVK = listGVK(CustomResourceDefinitionGVK)

	InfraEnvGKV = schema.GroupVersionKind{
		Group:   "agent-install.openshift.io",
		Version: "v1beta1",
		Kind:    "InfraEnv",
	}
	InfraEnvListGKV = listGVK(InfraEnvGKV)

	IngressControllerGVK = schema.GroupVersionKind{
		Group:   "operator.openshift.io",
		Version: "v1",
		Kind:    "IngressController",
	}
	IngressControllerListGVK = listGVK(IngressControllerGVK)

	ManagedClusterGVK = schema.GroupVersionKind{
		Group:   "cluster.open-cluster-management.io",
		Version: "v1",
		Kind:    "ManagedCluster",
	}
	ManagedClusterListGVK = listGVK(ManagedClusterGVK)

	NMStateConfigGVK = schema.GroupVersionKind{
		Group:   "agent-install.openshift.io",
		Version: "v1beta1",
		Kind:    "NMStateConfig",
	}
	NMStateConfigListGVK = listGVK(NMStateConfigGVK)
)

func listGVK(gvk schema.GroupVersionKind) schema.GroupVersionKind {
	gvk.Kind = gvk.Kind + "List"
	return gvk
}
