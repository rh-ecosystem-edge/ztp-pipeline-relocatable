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

package internal

import (
	"embed"
)

//go:embed data
var DataFS embed.FS

//go:generate -command get curl --silent --location --output
//go:generate get data/dev/crds/0010_ingresscontroller.yaml   https://raw.githubusercontent.com/openshift/api/release-4.12/operator/v1/0000_50_ingress-operator_00-ingresscontroller.crd.yaml
//go:generate get data/dev/crds/0011_icsp.yaml                https://raw.githubusercontent.com/openshift/api/release-4.12/operator/v1alpha1/0000_10_config-operator_01_imagecontentsourcepolicy.crd.yaml
//go:generate get data/dev/crds/0012_image.yaml               https://raw.githubusercontent.com/openshift/api/release-4.12/config/v1/0000_10_config-operator_01_image.crd.yaml
//go:generate get data/dev/crds/0015_agent.yaml               https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/agent-install.openshift.io_agents.yaml
//go:generate get data/dev/crds/0020_agentclusterinstall.yaml https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/extensions.hive.openshift.io_agentclusterinstalls.yaml
//go:generate get data/dev/crds/0030_clusterdeployment.yaml   https://raw.githubusercontent.com/openshift/hive/master/config/crds/hive.openshift.io_clusterdeployments.yaml
//go:generate get data/dev/crds/0040_managedcluster.yaml      https://raw.githubusercontent.com/open-cluster-management-io/api/v0.9.0/cluster/v1/0000_00_clusters.open-cluster-management.io_managedclusters.crd.yaml
//go:generate get data/dev/crds/0050_infraenv.yaml            https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/agent-install.openshift.io_infraenvs.yaml
//go:generate get data/dev/crds/0060_nmstateconfig.yaml       https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/agent-install.openshift.io_nmstateconfigs.yaml
//go:generate get data/dev/crds/0070_baremetalhost.yaml       https://raw.githubusercontent.com/metal3-io/baremetal-operator/v0.2.0/config/crd/bases/metal3.io_baremetalhosts.yaml
//go:generate get data/dev/crds/0080_olm.yaml                 https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/v0.23.1/deploy/upstream/quickstart/crds.yaml
//go:generate get data/dev/crds/0090_metallb.yaml             https://raw.githubusercontent.com/metallb/metallb-operator/v0.13.9/config/crd/bases/metallb.io_metallbs.yaml
//go:generate get data/dev/crds/0100_ipaddresspool.yaml       https://raw.githubusercontent.com/metallb/metallb-operator/v0.13.9/config/crd/bases/metallb.io_ipaddresspools.yaml
//go:generate get data/dev/crds/0110_l2adverisements.yaml     https://raw.githubusercontent.com/metallb/metallb-operator/v0.13.9/config/crd/bases/metallb.io_l2advertisements.yaml
//go:generate get data/dev/crds/0120_nmstate.yaml             https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/v0.76.0/deploy/crds/nmstate.io_nmstates.yaml
//go:generate get data/dev/crds/0130_ncnp.yaml                https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/v0.76.0/deploy/crds/nmstate.io_nodenetworkconfigurationpolicies.yaml
