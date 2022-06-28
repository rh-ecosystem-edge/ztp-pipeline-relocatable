#!/bin/bash

function set_firewall(){
    echo ">> Setting Firewall"
    firewall-cmd --zone=libvirt --add-port=6443/tcp --permanent
    firewall-cmd --zone=libvirt --add-service=dhcp --add-service=dhcpv6 --add-service=dns --add-service=mountd --add-service=nfs --add-service=rpc-bind --add-service=ssh --add-service=tftp --permanent
    firewall-cmd --reload
}

function checks() {
    echo 
    local fail=0
    local success=0
    echo ">> DNS Checks"
    echo ">>>> Checking External resolution"
    for interface in $(hostname -I)
    do
        if [[ "${interface}" =~  ^192.* ]]; then
            echo -n "== Interface ${interface}: "
            dig +short @${interface} quay.io | grep -v -e '^$'
            if [[ $? == 0 ]];then
                    let success++
            else
                    echo "Failed!"
                    let fail++
            fi
    
        fi
    
	
    done

    # Reset counter to 0 to check internal resolution
    local fail=0

    echo
    echo ">>>> Checking Hub Routes Internal resolution"
    for dns_name in "test.apps.test-ci.alklabs.local" "api.test-ci.alklabs.local" "api-int.test-ci.alklabs.local"
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

    if [[ $fail -gt 0 ]];then
        echo "ERROR: DNS Configuration has issues, check before continue"
        exit 1
    fi
}


function set_dnsmasq(){
    output=${1}
    echo ">> Configuring dnsmasq"
    echo "domain=test-ci.alklabs.local,192.168.150.0/24,local
resolv-file=/etc/resolv.upstream.conf

# Hub Cluster
address=/.apps.test-ci.alklabs.local/192.168.150.252
address=/api.test-ci.alklabs.local/192.168.150.253
address=/api-int.test-ci.alklabs.local/192.168.150.253

# Edge-cluster Cluster
address=/.apps.edgecluster0-cluster.alklabs.local/192.168.150.200
address=/api.edgecluster0-cluster.alklabs.local/192.168.150.201
address=/api-int.edgecluster0-cluster.alklabs.local/192.168.150.201" > ${output}

    touch /etc/resolv.upstream.conf
    cat /etc/resolv.conf /etc/resolv.upstream.conf | grep nameserver |grep -v 127.0.0.1  |sort -u > /etc/resolv.upstream.conf
}

