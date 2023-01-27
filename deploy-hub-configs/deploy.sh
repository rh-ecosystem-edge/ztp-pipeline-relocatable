#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

if ./verify.sh; then
    # Load common vars
    source ${WORKDIR}/shared-utils/common.sh

    echo ">>>> Wait until resources crd agentserviceconfig and clusterimageset ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    until oc --kubeconfig=${KUBECONFIG_HUB} get crd/agentserviceconfigs.agent-install.openshift.io >/dev/null 2>&1; do sleep 1; done
    until oc --kubeconfig=${KUBECONFIG_HUB} get crd/clusterimagesets.hive.openshift.io >/dev/null 2>&1; do sleep 1; done
    sleep 60

    echo ">>>> Preparing and replace info in the manifests"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    sed -i "s/CHANGEME/${OC_RHCOS_RELEASE}/g" 04-agent-service-config.yml
    sed -i "s/OC_OCP_VERSION_MIN/${OC_OCP_VERSION_MIN}/g" 04-agent-service-config.yml
    HTTPSERVICE=$(oc get routes -n default | grep httpd-server-route | awk '{print $2}')
    sed -i "s/HTTPD_SERVICE/${HTTPSERVICE}/g" 04-agent-service-config.yml
    pull=$(oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq -c)
    echo -n "  .dockerconfigjson: "\'$pull\' >>05-pullsecrethub.yml
    REGISTRY=ztpfw-registry

    HAS_REGISTRY=$(oc get --no-headers namespace ${REGISTRY} | wc -l)

    if [[ "${HAS_REGISTRY}" -eq "1" ]]; then
      LOCAL_REG="$(oc --kubeconfig=${KUBECONFIG_HUB} get configmap  --namespace ${REGISTRY} ztpfw-config -o jsonpath='{.data.uri}' | base64 -d)" #TODO change it to use the global common variable importing here the source commons
      sed -i "s/CHANGEDOMAIN/${LOCAL_REG}/g" registryconf.txt
      if [[ ${CUSTOM_REGISTRY} == "true" ]]; then
        export CA_CERT_DATA=$(openssl s_client -connect ${LOCAL_REG} -showcerts < /dev/null | openssl x509)
        echo "" >>01_Mirror_ConfigMap.yml
        echo "  ca-bundle.crt: |" >>01_Mirror_ConfigMap.yml
        echo -n "${CA_CERT_DATA}" | sed "s/^/    /" >>01_Mirror_ConfigMap.yml
      else
          CABUNDLE=$(oc get cm -n openshift-image-registry kube-root-ca.crt --template='{{index .data "ca.crt"}}')
          echo "  ca-bundle.crt: |" >>01_Mirror_ConfigMap.yml
          echo -n "${CABUNDLE}" | sed "s/^/    /" >>01_Mirror_ConfigMap.yml
      fi

      export REG_US=dummy
      export REG_PASS=dummy123
      registry_login ${LOCAL_REG}
      echo "" >>01_Mirror_ConfigMap.yml
      cat registryconf.txt >>01_Mirror_ConfigMap.yml

      echo "  mirrorRegistryRef:" >>04-agent-service-config.yml
      echo "    name: \"mirror-ref\"" >>04-agent-service-config.yml
      NEWTAG=$(skopeo inspect --tls-verify=false --format "{{.Name}}@{{.Digest}}" "docker://${LOCAL_REG}/openshift/release-images:${OC_OCP_TAG}")
    else
      NEWTAG="quay.io/openshift-release-dev/ocp-release:${OC_OCP_TAG}"
    fi
    sed -i "s/CHANGE_EDGE_CLUSTERIMAGESET/${CLUSTERIMAGESET}/g" 02-cluster_imageset.yml
    sed -i "s%TAG_OCP_IMAGE_RELEASE%${NEWTAG}%g" 02-cluster_imageset.yml

    # HACK for SNO to have DNS with DNSMasq
    # We need clustername and IP's and create entries

    # Check for already running DNS
    echo ">> Checking if there's a DNS service running"
    export NUM_M=$(oc --kubeconfig=${KUBECONFIG_HUB} get pods -A | grep coredns | wc -l)

    if [ "${NUM_M}" -eq "0" ]; then
        # Core DNS is not running, define variables and check if we're running DNSMasq instead

        # Get our domain from the console route and grab IP
        MYDOMAIN=$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n openshift-console console -o jsonpath={'.spec.host'} | sed -e "s/console-openshift-console\.apps\.//g")
        MYIP=$(ping api.$MYDOMAIN -c1 -W1 | grep ^PING | tr " " "\n" | grep "^(" | tr -d '()')

        echo ">> CoreDNS is not running, checking for alternate DNSMasq answering"
        echo "OCATOPICv1.0" | nc -v ${MYIP} 53 --wait 3s
        # Return code will be 0 in case someone answers...
        RC=$?

        if [ "${RC}" -eq "0" ]; then
            echo ">> DNSMasq is running, using it"
            # Fake number of NUM_M so that following tests will skip DNSMasq deployment
            NUM_M=1
        fi
    fi

    # Make sure that no config exists
    rm -f 06-coredns.yml
    if [ "${NUM_M}" == "0" ]; then

        DNSMAPPINGS=$(echo """
address=/apps.${MYDOMAIN}/${MYIP}
address=/api-int.${MYDOMAIN}/${MYIP}
address=/api.${MYDOMAIN}/${MYIP}
    """ | base64 -w0)

        DISPATCHER=$(
            cat <<EOF | base64 -w0
export IP="${MYIP}" # IP OF NODE (HUB)
export BASE_RESOLV_CONF=/run/NetworkManager/resolv.conf
if [ "\$2" = "dhcp4-change" ] || [ "\$2" = "dhcp6-change" ] || [ "\$2" = "up" ] || [ "\$2" = "connectivity-change" ]; then
	export TMP_FILE=\$(mktemp /etc/forcedns_resolv.conf.XXXXXX)
	cp  \$BASE_RESOLV_CONF \$TMP_FILE
	chmod --reference=\$BASE_RESOLV_CONF \$TMP_FILE
	sed -i -e "s/${MYDOMAIN}//" \
	-e "s/search / &
            ${MYDOMAIN} /" \
	-e "0,/nameserver/s/nameserver/ &
            \$IP\n &
            /" \$TMP_FILE
	mv \$TMP_FILE /etc/resolv.conf
fi
EOF
        )

        # Write the manifest file for CoreDNS
        cat <<EOF >06-coredns.yml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  creationTimestamp: "2022-05-03T15:12:42Z"
  generation: 1
  labels:
    machineconfiguration.openshift.io/role: master
  name: 50-master-dnsmasq-configuration
  resourceVersion: "1669"
  uid: ee2c44e0-ffcf-4903-bd96-9696bcd666ce
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents: # Query DNS for this
          source: data:text/plain;charset=utf-8;base64,${DNSMAPPINGS}
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/dnsmasq.d/single-node.conf
      - contents:
          source: data:text/plain;charset=utf-8;base64,${DISPATCHER}
          verification: {}
        filesystem: root
        mode: 365
        path: /etc/NetworkManager/dispatcher.d/forcedns
      - contents:
          source: data:text/plain;charset=utf-8;base64,ClttYWluXQpyYy1tYW5hZ2VyPXVubWFuYWdlZAo=
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/NetworkManager/conf.d/single-node.conf
    systemd:
      units:
      - contents: |
          [Unit]
          Description=Run dnsmasq to provide local dns for Single Node OpenShift
          Before=kubelet.service crio.service
          After=network.target

          [Service]
          ExecStart=/usr/sbin/dnsmasq -k

          [Install]
          WantedBy=multi-user.target
        enabled: true
        name: dnsmasq.service
EOF

    fi
    echo ">>>> Deploy hub configs"
    echo ">>>>>>>>>>>>>>>>>>>>>>>"
    if [[ "${HAS_REGISTRY}" -eq "1" ]]; then
      oc --kubeconfig=${KUBECONFIG_HUB} apply -f 01_Mirror_ConfigMap.yml
    fi
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f 02-cluster_imageset.yml
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f 03-configmap.yml
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f 04-agent-service-config.yml
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f 05-pullsecrethub.yml

    echo ">>>> Wait for Assisted services deployed"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    while [[ $(oc get pod -n multicluster-engine | grep assisted | wc -l) -eq 0 ]]; do
        echo "Waiting for Assisted installer to be ready..."
        sleep 5
    done
    check_resource "deployment" "assisted-service" "Available" "multicluster-engine" "${KUBECONFIG_HUB}"

else

    echo ">>>> This step is not neccesary, everything looks ready"
fi

if [ -f 06-coredns.yml ]; then
    echo ">>>> Applying Fire and Forget DNSMasq config"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f 06-coredns.yml --wait=False
fi

echo ">>>>EOF"
echo ">>>>>>>"
