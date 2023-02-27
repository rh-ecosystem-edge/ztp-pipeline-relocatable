#!/usr/bin/bash

{{ if .Node.InternalNIC -}}
DEV="{{ .Node.InternalNIC.Name }}"
{{ else -}}
DEV="br-ex"
{{ end -}}
{{ if .Node -}}
NODE_IP="{{ .Node.InternalIP.Address }}"
{{ else -}}
NODE_IP=""
{{ end -}}

NUM_INT_IP=$(ip -j -4 a s | jq -r 'map(select(.addr_info[0].local | startswith("192.168.7"))) | length')
NUM_INT_IP_DEV=$(ip -j -4 a s dev $1 | jq -r 'map(select(.addr_info[0].local | startswith("192.168.7"))) | length')

if [[ $NUM_INT_IP -ne 0 ]] && [[ $NUM_INT_IP_DEV -eq 0 ]];
then
    echo "The host already has an IP on the internal subnet: Skipping IP assignment on iface ${DEV}"
    ip -4 a s
    exit 0
fi

if [[ "$1" == "${DEV}"  ]] && [ $NUM_INT_IP_DEV -eq 0 ];
then
    if [[ "${NODE_IP}" == "" ]];
    then
	 NEW_IP=$(nmcli conn show ${DEV}.0 | grep "ipv4.addresses" | awk '{split($2, a, "/"); print a[1]}')
    else
	 NEW_IP=${NODE_IP}
    fi

    nmcli connection modify ${DEV} +ipv4.addresses ${NEW_IP}/24 ipv4.method auto
    ip addr add ${NEW_IP}/24 dev ${DEV}
fi
