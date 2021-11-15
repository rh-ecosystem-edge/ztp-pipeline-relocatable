#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

echo ">>>> Download jq, oc, kubectl and set bash completion"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 >/usr/bin/jq
chmod u+x /usr/bin/jq

if [ ! -d "/root/bin" ]; then
    mkdir -p /root/bin
    export PATH="$PATH:/root/bin"
fi

cd /root/bin
curl -k -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz >oc.tar.gz
tar zxf oc.tar.gz
rm -rf oc.tar.gz
mv oc /usr/bin
chmod +x /usr/bin/oc

curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl
chmod u+x /usr/bin/kubectl

oc completion bash >>/etc/bash_completion.d/oc_completion

echo ">>>> EOF"
echo ">>>>>>>>"
