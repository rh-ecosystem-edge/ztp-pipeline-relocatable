#!/usr/bin/bash

# This script will only be present in nodes that don't have an internal NIC. For those nodes we need
# to add the internal IP to the external NIC.
external_dev="{{ .ExternalNIC.Name }}"
internal_ip="{{ .InternalIP }}"
nmcli connection modify "${external_dev}" +ipv4.addresses "${internal_ip}" ipv4.method auto
ip addr add "${internal_ip}" dev "${external_dev}"