#!/usr/bin/env bash


function set_dnsmasq_spoke(){
    if [[ $(hostname |grep flavio) ]];then
      export ROUTE_DEST=/etc/dnsmasq.d/01-spoke0-cluster.con
    else
      export ROUTE_DEST=/etc/NetworkManager/dnsmasq.d/01-spoke0-cluster.conf
    fi
    if [[ "$1" == "compact" ]]; then
       echo "resolv-file=/etc/resolv.upstream.conf
      # Spoke Cluster
      address=/.apps.spoke0-cluster.alklabs.local/192.168.150.200
      address=/api.spoke0-cluster.alklabs.local/192.168.150.201
      address=/api-int.spoke0-cluster.alklabs.local/192.168.150.201" > "${ROUTE_DEST}"

    fi
    if [[ "$1" == "sno" ]]; then
       echo "resolv-file=/etc/resolv.upstream.conf
      # Spoke Cluster
      address=/.apps.spoke0-cluster.alklabs.local/192.168.150.201
      address=/api.spoke0-cluster.alklabs.local/192.168.150.201
      address=/api-int.spoke0-cluster.alklabs.local/192.168.150.201" > "${ROUTE_DEST}"
    fi
}

function restart_services(){
    echo ">> Restarting Services"
    systemctl restart NetworkManager
    if [[ $(hostname |grep flavio) ]];then
      systemctl enable  dnsmasq
      systemctl restart dnsmasq
    else
      systemctl disable  dnsmasq
    fi
    systemctl restart libvirtd
    systemctl restart sushy
}

function checks() {
    echo
    local fail=0
    local success=0
    echo ">> DNS Checks"

    echo ">>>> Checking Spoke Routes Internal resolution"
    for dns_name in "test.apps.spoke0-cluster.alklabs.local" "api.spoke0-cluster.alklabs.local" "api-int.spoke0-cluster.alklabs.local"
    do
        echo -n "${dns_name}: "
        dig +short @192.168.150.1 ${dns_name} | grep -v -e '^$'
        if [[ $? == 0 ]];then
            let success++
        else
            echo "Failed!"
            let fail++
        fi
    done

    if [[ $fail > 0 ]];then
        echo "ERROR: DNS Configuration has issues, check before continue"
        exit 1
    fi


}
if [[ $# -eq 0 ]];then
    echo "Usage: $0 [compact|sno]"
    exit 1
fi

echo ">> Configuring Spokes with $1"
set_dnsmasq_spoke $1
restart_services
checks "spokes"