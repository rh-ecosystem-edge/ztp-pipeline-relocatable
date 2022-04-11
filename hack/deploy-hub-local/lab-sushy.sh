#!/bin/bash

PS_SUSHY=$(ps -ef | grep py | grep sushy)
if [ -z "$PS_SUSHY" ]; then
  dnf -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 git python3-netifaces
  pip3 install sushy-tools
  systemctl enable --now sushy

  python3 ./helpers/sushy.py

  firewall-cmd --zone=libvirt --permanent --add-port=8000/tcp

fi