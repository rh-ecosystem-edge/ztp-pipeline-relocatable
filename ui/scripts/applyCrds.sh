#!/bin/bash

#    AI CRDs https://github.com/openshift/assisted-service/tree/master/config/crd/bases
#    NMState Operator CRDs: https://github.com/nmstate/kubernetes-nmstate/tree/main/deploy/crds
#    MetalLB CRDs: https://github.com/metallb/metallb-operator/tree/main/config/crd/bases

curl https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/main/deploy/crds/nmstate.io_nmstates.yaml | oc apply -f -
curl https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/main/deploy/crds/nmstate.io_nodenetworkconfigurationenactments.yaml | oc apply -f -
curl https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/main/deploy/crds/nmstate.io_nodenetworkconfigurationpolicies.yaml | oc apply -f -
curl https://raw.githubusercontent.com/nmstate/kubernetes-nmstate/main/deploy/crds/nmstate.io_nodenetworkstates.yaml | oc apply -f -

curl https://raw.githubusercontent.com/metallb/metallb-operator/main/config/crd/bases/metallb.io_addresspools.yaml | oc apply -f -
curl https://raw.githubusercontent.com/metallb/metallb-operator/main/config/crd/bases/metallb.io_bfdprofiles.yaml | oc apply -f -
curl https://raw.githubusercontent.com/metallb/metallb-operator/main/config/crd/bases/metallb.io_bgppeers.yaml | oc apply -f -
curl https://raw.githubusercontent.com/metallb/metallb-operator/main/config/crd/bases/metallb.io_metallbs.yaml | oc apply -f -
