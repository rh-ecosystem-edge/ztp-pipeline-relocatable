#!/usr/bin/bash

# This is needed because this script is included in the ignition configuration that is part of the
# discovery ISO, and that is shared by all the nodes of the cluster. We have the MAC and and
# internal IP addresses of all the nodes that need an additional IP address added to the external
# NIC. We iterate that list and if we find a matching NIC we add the corresponding IP address.
while read exernal_mac internal_ip; do
  external_dev=$(
    ip -j link |
    jq -r ".[] | select(.address == \"${exernal_mac}\") | .ifname"
  )
  if [ -z "${external_dev}" ]; then
    continue
  fi
  nmcli connection modify "${external_dev}" +ipv4.addresses "${internal_ip}" ipv4.method auto
  ip addr add "${internal_ip}" dev "${external_dev}"
done <<.
{{ range .Cluster.Nodes -}}
{{ if not .InternalNIC -}}
{{ .ExternalNIC.MAC }} {{ .InternalIP }}
{{ end -}}
{{ end -}}
.
