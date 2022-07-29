#!/bin/bash 
tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  vshpere-clusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults pre-flight
tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  vshpere-clusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-httpd-server
tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  vshpere-clusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-disconnected-registry
tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  vshpere-clusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-acm
tkn task start -n edgecluster-deployer -p ztp-container-image="quay.io/takinosh/pipeline:vsphere" -p edgeclusters-config="$(cat  vshpere-clusters.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-openshift-ztp-aap


