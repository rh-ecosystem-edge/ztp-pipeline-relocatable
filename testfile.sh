set -x

function check_resource() {
    # 1 - Resource type: "deployment"
    # 2 - Resource name: "openshift-pipelines-operator"
    # 3 - Type Status: "Available"
    # 4 - Namespace: "openshift-operators"
    # 5 - Kubeconfig: ""

    if [[ -z ${1} ]]; then
        echo "I need a resource to check, value passed: \"${1}\""
        exit 1
    fi

    if [[ -z ${2} ]]; then
        echo "I need a resource name to check, value passed: \"${2}\""
        exit 1
    fi

    if [[ -z ${3} ]]; then
        echo "I need a Type Status (E.G 'Available') from status.conditions json field to check, value passed: \"${3}\""
        exit 1
    fi

    if [[ -z ${4} ]]; then
        echo "I need a Namespace to check the resource into, value passed: \"${4}\""
        exit 1
    fi

    if [[ -z ${5} ]]; then
        echo "I need a Kubeconfig, value passed: \"${5}\""
        exit 1
    fi

    RESOURCE="${1}"
    RESOURCE_NAME="${2}"
    TYPE_STATUS="${3}"
    NAMESPACE="${4}"
    KUBE="${5}"


    echo "RESOURCE=$RESOURCE"
    echo "RESOURCE_NAME=$RESOURCE_NAME"
    echo "TYPE_STATUS=$TYPE_STATUS"
    echo "NAMESPACE=$NAMESPACE"
    echo "KUBE=$KUBE"

    echo ">>>> Checking Resource: ${RESOURCE} with name ${RESOURCE_NAME}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "1000" ]; do
        if [[ $(oc --kubeconfig=${KUBE} -n ${NAMESPACE} get ${RESOURCE} ${RESOURCE_NAME} -o jsonpath="{.status.conditions[?(@.type==\"${TYPE_STATUS}\")].status}") == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for ${RESOURCE} ${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        sleep 20
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for ${RESOURCE}-${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        exit 1
    fi
}
