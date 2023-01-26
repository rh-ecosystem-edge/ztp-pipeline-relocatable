#!/usr/bin/bash



DEV=${STATIC_IP_INTERFACE}
NUM_INT_IP=$(ip -j -4 a s dev $1 | jq -r 'map(select(.addr_info[0].local | startswith("192.168.7"))) | length')

if [[ "$1" == "${DEV}"  ]] && [ $NUM_INT_IP -eq 0 ];
then
    if [[ "${NODE_IP}" == "" ]];
    then
	 EXT_IP=$(ip -j -4 a s dev ${DEV} | jq -r ".[0].addr_info[0].local")
	 IP_SUFFIX=$(echo $EXT_IP | awk -F. '{print $4}')
	 NEW_IP="192.168.7.${IP_SUFFIX}"
    else
	 NEW_IP=${NODE_IP}
    	 nmcli connection modify ${DEV} +ipv4.addresses ${NEW_IP}/24 ipv4.method auto
    fi

    ip addr add ${NEW_IP}/24 dev ${DEV}
fi
