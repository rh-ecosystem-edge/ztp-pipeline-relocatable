#!/bin/bash

set -o pipefail
set -o nounset
set -m

# TODO
# hub
# - Update tarball for faster times (snapshot update as day 2 ops)
# spoke
# - mirror the remaining updates

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh hub

MODE=${1}

SNAPSHOTFILE="mirror-snapshot.tgz"
HTTPSERVICE=$(oc --kubeconfig=${KUBECONFIG_HUB} get routes -n default | grep httpd-server-route | awk '{print $2}')
DOCKERPATH="/var/lib/registry/docker"
HTTPDPATH="/var/www/html"
REGISTRY_POD=$(oc --kubeconfig=${KUBECONFIG_HUB} get pod -n ${REGISTRY} -l name=${REGISTRY} -oname | head -1 | cut -d "/" -f2-)

if [[ ${MODE} == 'hub' ]]; then

    HTTPD_POD=$(oc --kubeconfig=${KUBECONFIG_HUB} get pod -n default -oname | grep httpd | head -1 | cut -d "/" -f2-)

    # Execute from node with the http and store in httpd path

    # Get local tarball from REGISTRY
    oc --kubeconfig=${KUBECONFIG_HUB} exec -i -n ${REGISTRY} ${REGISTRY_POD} -- tar czf - ${DOCKERPATH} >/var/tmp/${SNAPSHOTFILE}

    # Upload local tarball to HTTPD
    oc --kubeconfig=${KUBECONFIG_HUB} -n default cp /var/tmp/${SNAPSHOTFILE} ${HTTPD_POD}:${HTTPDPATH}/${SNAPSHOTFILE}

elif [[ ${MODE} == 'spoke' ]]; then
    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    # Get HTTPD path (common for all spokes)
    URL="http://${HTTPSERVICE}/${SNAPSHOTFILE}"

    for spoke in ${ALLSPOKES}; do
        # Restore
        echo "spoke: ${spoke}"
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig_common ${spoke}
        else
            export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi

        # Run on the target registry the command to download the snapshot (wget comes within busybox)
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- wget -O /var/lib/registry/docker/patata.tgz ${URL}

        # Uncompress from the / folder
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- tar xvzf -C / /var/lib/registry/docker/patata.tgz

        # Cleanup downloaded file
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- rm -fv /var/lib/registry/docker/patata.tgz

    done
fi
