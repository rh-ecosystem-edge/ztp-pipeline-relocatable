#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

function set_route() {
   INT_DEV=$(ip -j a s | jq -r '[ .[] | .addr_info[] | select( .local | contains("192.168.7")) ][0].label // ""')

   if [[ $INT_DEV == "" ]]; then
      echo "No device for 192.168.7.0/24"
      sleep 1
      return 
   fi

   INT_GATEWAY=192.168.7.1
   EXT_IFACE=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7") | not) ][0].dev')
   
   INT_METRIC=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7")) ][0].metric // 0')
   EXT_METRIC=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7") | not) ][0].metric // 0')
   EXT_GATEWAY=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7") | not) ][0].gateway')
   EXT_PROTOCOL=$(ip -j route list default | jq -r '[ .[] | select( .gateway | contains("192.168.7") | not) ][0].protocol')

   if [[ $INT_DEV == $EXT_IFACE ]];
   then
      EXT_IP=$(ip -j -4 a s dev ${EXT_IFACE} | jq -r ".[0].addr_info[0].local")
      IP_SUFFIX=$(echo $EXT_IP | awk -F. '{print $4}')
      INT_GATEWAY="192.168.7.$IP_SUFFIX"
   fi

   if [[ $INT_METRIC -eq 0 && $INT_DEV == $EXT_IFACE ]]; then
        echo "Secondary IP mode detected but no route for the internal network"
        echo "ip route add default via $INT_GATEWAY dev ${INT_DEV} proto kernel metric $((EXT_METRIC - 1))"
	ip route add default via $INT_GATEWAY dev $INT_DEV proto kernel metric $((EXT_METRIC - 1))
   elif [[ $INT_METRIC -eq 0 && $INT_DEV != "br-ex" ]]; then
        echo "Internal network route doesn't exist: adding a new route for the internal network"
        echo "ip route add default via $INT_GATEWAY dev ${INT_DEV} proto kernel metric $((EXT_METRIC + 1))"
	ip route add default via $INT_GATEWAY dev $INT_DEV proto kernel metric $((EXT_METRIC + 1))
   elif [[ $INT_METRIC -eq 0 && $INT_DEV == "br-ex" ]]; then
        echo "Bridge network route doesn't exist: adding a new route for the bridge network"
        echo "ip route add default via $INT_GATEWAY dev ${INT_DEV} proto kernel metric $((EXT_METRIC + 1))"
	ip route add default via $INT_GATEWAY dev $INT_DEV proto kernel metric $((EXT_METRIC + 1))
    elif [[ $INT_METRIC -gt 0 && $INT_METRIC -lt $EXT_METRIC && $INT_DEV == "br-ex" ]]; then
        echo "Internal network metric is lower: adding a new metric for the external network"
        echo "ip route add default via $EXT_GATEWAY dev $EXT_IFACE proto $EXT_PROTOCOL metric $((INT_METRIC - 1))"
        ip route add default via $EXT_GATEWAY dev $EXT_IFACE proto $EXT_PROTOCOL metric $((INT_METRIC - 1))
        ip route delete default via $EXT_GATEWAY dev $EXT_IFACE proto $EXT_PROTOCOL metric $EXT_METRIC
    fi
    sleep 120
}

while true; do
    #set_route
    sleep 120
done
