#!/usr/bin/env bash

source lab-dns-common.sh

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


function restart_services(){
    echo ">> Restarting Services"
    systemctl disable --now dnsmasq
    systemctl restart NetworkManager
    systemctl restart libvirtd sushy
}



set_firewall
disable_nm_dnsmasq
set_dnsmasq /etc/NetworkManager/dnsmasq.d/00-test-ci.conf
restart_services
checks
