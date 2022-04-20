#!/bin/bash

PS_SUSHY=$(ps -ef | grep py | grep sushy)
if [ -z "$PS_SUSHY" ]; then
  cp ./lab-sushy.conf /etc/sushy.conf
  cp ./lab-sushy.service /etc/systemd/system/sushy.service

  dnf -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 git python3-netifaces
  pip3 install sushy-tools --ignore-installed PyYAML || true
  systemctl daemon-reload
  systemctl enable --now sushy.service

  firewall-cmd --zone=libvirt --permanent --add-port=8000/tcp
  firewall-cmd --reload
  systemctl start sushy.service
else
  echo "Sushy is already running"
fi