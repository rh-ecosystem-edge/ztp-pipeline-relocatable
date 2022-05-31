#!/usr/bin/env bash

function set_firewall(){
    echo ">> Setting Firewall"
    firewall-cmd --zone=libvirt --add-port=6443/tcp --permanent
    firewall-cmd --zone=libvirt --add-service=dhcp --add-service=dhcpv6 --add-service=dns --add-service=mountd --add-service=nfs --add-service=rpc-bind --add-service=ssh --add-service=tftp --permanent
    firewall-cmd --reload
}

function disable_nm_dnsmasq(){
    echo ">> Disabling NetworkManager's dnsmasq"
    echo "[main]
dns=dnsmasq" > /etc/NetworkManager/conf.d/00-dnsmasq.conf

    export hostname=$(hostname -f)
    echo ">>>> Configuring IPTables"
    iptables -C FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24 2>&1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule ztpfw > bare-net..."
        iptables -I FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24
        firewall-cmd --reload
    fi

    iptables -C FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24 2>&1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule bare-net > ztpfw..."
        iptables -I FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24
        firewall-cmd --reload
    fi 

    echo ">>>> Prunning /etc/hosts"
    echo "127.0.0.1 localhost.localdomain localhost" > /etc/hosts
}

function set_nm_dnsmasq(){
    echo ">> Configuring NetworkManager's dnsmasq"
    echo "domain=test-ci.alklabs.local,192.168.150.0/24,local
resolv-file=/etc/resolv.upstream.conf

# Hub Cluster
address=/.apps.test-ci.alklabs.local/192.168.150.252
address=/api.test-ci.alklabs.local/192.168.150.253
address=/api-int.test-ci.alklabs.local/192.168.150.253
# Edge-cluster Cluster
address=/.apps.edgecluster0-cluster.alklabs.local/192.168.150.200
address=/api.edgecluster0-cluster.alklabs.local/192.168.150.201
address=/api-int.edgecluster0-cluster.alklabs.local/192.168.150.201" > /etc/NetworkManager/dnsmasq.d/00-test-ci.conf

    cat /etc/resolv.conf | grep nameserver > /etc/resolv.upstream.conf
}

function restart_services(){
    echo ">> Restarting Services"
    systemctl disable --now dnsmasq
    systemctl restart NetworkManager
    systemctl restart libvirtd sushy
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

    if [[ $fail > 0 ]];then
        echo "ERROR: DNS Configuration has issues, check before continue"
        exit 1
    fi
}

set_hostname
set_firewall
disable_nm_dnsmasq
set_nm_dnsmasq
restart_services
checks
