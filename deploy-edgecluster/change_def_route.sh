#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

function set_route() {
    INT_METRIC=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7.1")) ][0].metric')
    EXT_METRIC=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7.1") | not) ][0].metric')

    if [[ $INT_METRIC -lt $EXT_METRIC ]]; then
        EXT_GATEWAY=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7.1") | not) ][0].gateway')
        EXT_IFACE=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7.1") | not) ][0].dev')
        EXT_PROTOCOL=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7.1") | not) ][0].protocol')

        echo "Internal network metric is lower: adding a new metric for the external network"
        echo "ip route add default view $EXT_GATEWAY dev $EXT_IFACE proto $EXT_PROTOCOL metric $((INT_METRIC - 1))"
        ip route add default via $EXT_GATEWAY dev $EXT_IFACE proto $EXT_PROTOCOL metric $((INT_METRIC - 1))
    fi
}

while true; do
    sleep 120
    set_route
done
