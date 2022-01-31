#!/usr/bin/env bash

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
function check_cluster() {
    TIMEOUT=120
    MODE=${1}

    echo ">> Checking MCP in: ${MODE}"
    if [[ ${MODE} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=hub
    elif [[ ${MODE} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        cluster=${2}
    fi

    echo ">> Waiting for the MCO to grab the new MachineConfig for the registry certificate..."
    sleep 120

    echo ">>>> Waiting for MCP Updated field on: ${MODE}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        echo KUBECONFIG=${TARGET_KUBECONFIG}
        if [[ $(oc --kubeconfig=${TARGET_KUBECONFIG} get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}') == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for MCP Updated field on: ${MODE}"
        sleep 5
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for MCP Updated field on: ${MODE}"
        exit 1
    fi

    echo ">> Checking nodes for ${MODE}"
    for node in $(oc --kubeconfig=${TARGET_KUBECONFIG} get nodes -o name); do
        KBLT_RDY=$(oc --kubeconfig=${TARGET_KUBECONFIG} get ${node} -o jsonpath='{.status.conditions[?(@.reason=="KubeletReady")].status}')
        if [[ ${KBLT_RDY} != 'True' ]]; then
            echo ">> Kubelet of node ${node} Not Ready, waiting ${TIMEOUT} secs"
            sleep ${TIMEOUT}
        else
            echo ">> Mode: ${MODE} Node: ${node} Verified"
        fi
    done
}

source ${WORKDIR}/shared-utils/common.sh
source ./common.sh hub

MODE=${1}

SNAPSHOTFILE="mirror-snapshot.tgz"
HTTPSERVICE=$(oc --kubeconfig=${KUBECONFIG_HUB} get routes -n default | grep httpd-server-route | awk '{print $2}')
DOCKERPATH="/var/lib/registry/docker"
HTTPDPATH="/var/www/html"

if [[ ${MODE} == 'hub' ]]; then

    HTTPD_POD=$(oc --kubeconfig=${KUBECONFIG_HUB} get pod -n default -oname | grep httpd | head -1 | cut -d "/" -f2-)
    REGISTRY_POD=$(oc --kubeconfig=${KUBECONFIG_HUB} get pod -n ${REGISTRY} -l name=${REGISTRY} -oname | head -1 | cut -d "/" -f2-)
    # Execute from node with the http and store in httpd path
    check_cluster ${MODE}

    echo ">> Mirroring the registry snapshot only if it does not exist previously"
    if [[ ! -f /var/tmp/${SNAPSHOTFILE} ]]; then
      # Get local tarball from REGISTRY
      oc --kubeconfig=${KUBECONFIG_HUB} exec -i -n ${REGISTRY} ${REGISTRY_POD} -- tar czf - ${DOCKERPATH} >/var/tmp/${SNAPSHOTFILE}

      # Upload local tarball to HTTPD
      oc --kubeconfig=${KUBECONFIG_HUB} -n default cp /var/tmp/${SNAPSHOTFILE} ${HTTPD_POD}:${HTTPDPATH}/${SNAPSHOTFILE}
    else
      echo ">> Mirroring the registry snapshot already exists"
    fi

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

        REGISTRY_POD=$(oc --kubeconfig=${SPOKE_KUBECONFIG} get pod -n ${REGISTRY} -l name=${REGISTRY} -oname | head -1 | cut -d "/" -f2-)

        check_cluster "${MODE}" "${spoke}"

        # Run on the target registry the command to download the snapshot (wget comes within busybox)
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- curl -o /var/lib/registry/ocatopic.tgz ${URL}

        # Uncompress from the / folder
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- tar xvzf /var/lib/registry/ocatopic.tgz -C /

        # Cleanup downloaded file
        oc exec --kubeconfig=${SPOKE_KUBECONFIG} -n ${REGISTRY} ${REGISTRY_POD} -- rm -fv /var/lib/registry/ocatopic.tgz

    done
fi
