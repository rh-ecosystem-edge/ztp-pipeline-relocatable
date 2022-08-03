#!/bin/bash 
####
## 1. Deploy cluster using https://github.com/kenmoini/ocp4-ai-svc-libvirt
## 2. Configure ODF
## 3. git clone Git clone https://github.com/tosin2013/ztp-pipeline-relocatable.git && git checkout vsphere
## 4. create edgeclusters.yaml
## 5. Start Script below 
## Testing connected install first
####
export DISCONNECT_INSTALL=false

if [ "$DISCONNECT_INSTALL" = true ]; then
    echo "Disconnected tasks for  vSphere"
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults common-pre-flight
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults hub-deploy-httpd-server
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults hub-deploy-disconnected-registry
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults hub-deploy-acm
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-openshift-ztp-aap
else
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults common-pre-flight
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults hub-deploy-acm
    tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  edgeclusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-openshift-ztp-aap
fi


