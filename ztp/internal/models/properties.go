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

// This file contains constants for names of commonly used configuration properties:

// OCPVersionProperty is the name of the property used to define the OpenShift version to be used
// for the installation of clusters.
const OCPVersionProperty = "OC_OCP_VERSION"

// OCPTagProperty is the image tag of the OpenShift version. If not specified then the tag will be
// calculated adding the `-x86_64` suffix. For example, of the value of `OC_OCP_VERSION` is
// `4.10.38` then the value of this will be `4.10.38-x86_64`.
const OCPTagProperty = "OC_OCP_TAG"

// OCPRCHOSReleaseProperty is the full release number of the Red Hat Enterprise Linux CoreOS to be
// used for the installation of clusters. If not specified this will be extracted from the
// `release.txt` file corresponding to the version specified in `OC_OCP_VERSION`.
const OCPRCHOSReleaseProperty = "OC_RHCOS_RELEASE"

// OCPMirrorProperty is the base URL for the OCP mirror that will be used to download the
// `release.txt` file. The default is to use `https://mirror.openshift.com/pub/openshift-v4/clients/ocp/`
// and there is usually no need to change it. This is only intended for use in unit tests.
const OCPMirrorProperty = "OC_OCP_MIRROR"

// ClusterImageSetProperty is the name of the Hive cluster image set that will be used for the
// installation of the cluster. The default is to calculate it from the OCM version. For example, if
// the OCP version is `4.10.38` then the value will be `openshift-v4.10.38`.
const ClusterImageSetProperty = "clusterimageset"

// RegistryProperty is the URL of a custom image registry to use for the clusters.
const RegistryProperty = "REGISTRY"
