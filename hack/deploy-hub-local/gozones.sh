#!/bin/bash
## https://computingforgeeks.com/how-to-disable-ipv6-on-linux/
### libvirt networks 
kcli create network --nodhcp -c 192.168.7.0/24 ztpfw
kcli create network -c 192.168.150.0/24 bare-net

## Set vars
MIRROR_BASE_PATH="/opt/disconnected-mirror"
MIRROR_VM_HOSTNAME="dns"
MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP="192.168.150.1"
ISOLATED_NETWORK_DOMAIN="rtoztplab.com"
ISOLATED_NETWORK_CIDR="192.168.150.0/24"
FORWARD_IP="1.1.1.1"

cat  >/etc/sysctl.d/ipv6.conf<<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

FORWARD_IP="10.11.5.19"
# Create the YAML File
mkdir -p ${MIRROR_BASE_PATH}/dns/volumes/go-zones/
mkdir -p ${MIRROR_BASE_PATH}/dns/volumes/bind/
curl -L https://raw.githubusercontent.com/kenmoini/go-zones/main/container_root/opt/app-root/vendor/bind/named.conf  --output $MIRROR_BASE_PATH/dns/volumes/bind/named.conf
ls -alth  $MIRROR_BASE_PATH/dns/volumes/bind/named.conf || exit $?
cat > $MIRROR_BASE_PATH/dns/volumes/go-zones/zones.yml <<EOF
zones:
  - name: $ISOLATED_NETWORK_DOMAIN
    subnet: $ISOLATED_NETWORK_CIDR
    network: internal
    primary_dns_server: $MIRROR_VM_HOSTNAME.$ISOLATED_NETWORK_DOMAIN
    ttl: 3600
    records:
      NS:
        - name: $MIRROR_VM_HOSTNAME
          ttl: 86400
          domain: $ISOLATED_NETWORK_DOMAIN.
          anchor: '@'
      A:
        - name: $MIRROR_VM_HOSTNAME
          ttl: 6400
          value: $MIRROR_VM_ISOLATED_BRIDGE_IFACE_IP
        - name: api.ocp4
          ttl: 6400
          value: 192.168.150.253
        - name: api-int.ocp4
          ttl: 6400
          value: 192.168.150.253
        - name: '*.apps.ocp4'
          ttl: 6400
          value: 192.168.150.252
        - name: api.spoke0-cluster
          ttl: 6400
          value: 192.168.150.201
        - name: api-int.spoke0-cluster
          ttl: 6400
          value: 192.168.150.201
        - name: '*.apps.spoke0-cluster'
          ttl: 6400
          value: 192.168.150.200
        - name: 'esxi'
          ttl: 6400
          value: 192.168.150.202
        - name: 'vsphere'
          ttl: 6400
          value: 192.168.150.203
EOF

## Create a forwarder file to redirect all other inqueries to this Mirror VM
mkdir -p ${MIRROR_BASE_PATH}/dns/volumes/bind/
cat > $MIRROR_BASE_PATH/dns/volumes/bind/external_forwarders.conf <<EOF
forwarders {
  127.0.0.53;
  ${FORWARD_IP};
};
EOF

podman run -d --name dns-go-zones \
 --net host \
 -m 512m \
 -v $MIRROR_BASE_PATH/dns/volumes/go-zones:/etc/go-zones/:Z \
 -v $MIRROR_BASE_PATH/dns/volumes/bind:/opt/app-root/vendor/bind/:Z \
 quay.io/kenmoini/go-zones:file-to-bind


podman generate systemd \
    --new --name dns-go-zones \
    > /etc/systemd/system/dns-go-zones.service

systemctl enable dns-go-zones
systemctl start dns-go-zones
systemctl status dns-go-zones
sudo firewall-cmd --add-service=dns --permanent
sudo firewall-cmd --reload


dig  @127.0.0.1 test.apps.ocp4.${ISOLATED_NETWORK_DOMAIN}
dig  @192.168.150.1 test.apps.ocp4.${ISOLATED_NETWORK_DOMAIN}
dig  @127.0.0.1 test.apps.spoke0-cluster.${ISOLATED_NETWORK_DOMAIN}
dig  @192.168.150.1 test.apps.spoke0-cluster.${ISOLATED_NETWORK_DOMAIN}
