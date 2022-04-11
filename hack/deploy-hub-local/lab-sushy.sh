#!/bin/bash

PS_SUSHY=$(ps -ef | grep py | grep sushy)
if [ -z "$PS_SUSHY" ]; then
  cp ./lab-sushy.conf /etc/sushy.conf

  dnf -y install podman pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 git python3-netifaces

  export SUSHY_TOOLS_IMAGE=${SUSHY_TOOLS_IMAGE:-"quay.io/metal3-io/sushy-tools"}
  podman create --net host --privileged --name sushy-emulator -v "/etc":/etc -v "/var/run/libvirt":/var/run/libvirt "${SUSHY_TOOLS_IMAGE}" sushy-emulator -i :: -p 8000 --config /etc/sushy.conf

  podman generate systemd --restart-policy=always -t 1 sushy-emulator > /etc/systemd/system/sushy-emulator.service
  systemctl daemon-reload
  systemctl enable --now sushy-emulator.service
  sleep 10
  systemctl start sushy-emulator.service

  firewall-cmd --zone=libvirt --permanent --add-port=8000/tcp

fi