#!/usr/bin/env bash
set -euo pipefail

#clean before
> /etc/exports

# install the nfs
export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
export PRIMARY_IP=192.168.150.1
dnf -y install nfs-utils
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in ${PVS}; do
	export PV=pv$(printf "%03d" ${i})
	mkdir /${PV} ||true
	echo "/${PV} *(rw,no_root_squash)" >>/etc/exports
	chcon -t svirt_sandbox_file_t /${PV}
	chmod 777 /${PV}
	[ "${i}" -gt "10" ] && export MODE="ReadWriteMany"
	envsubst <./nfs.yml | oc apply -f -
done
exportfs -r

firewall-cmd --zone=libvirt --permanent --add-service=nfs
firewall-cmd --zone=libvirt --permanent --add-service=mountd
firewall-cmd --zone=libvirt --permanent --add-service=rpc-bind
firewall-cmd --reload
