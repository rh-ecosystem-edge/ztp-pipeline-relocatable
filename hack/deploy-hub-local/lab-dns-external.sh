#!/usr/bin/env bash

function set_hostname(){
    echo ">> Setting Hostname"
    local host=$(hostname -s)
    if [[ -z ${host} ]];then
        uuid=$(echo "$(uuidgen)" | cut -f1 -d\-)
        host="flavio-${uuid}"
    fi
    hostnamectl set-hostname ${host}.alklabs.local
}

function set_firewall(){
    echo ">> Setting Firewall"
    firewall-cmd --zone=libvirt --add-port=6443/tcp --permanent
    firewall-cmd --zone=libvirt --add-service=dhcp --add-service=dhcpv6 --add-service=dns --add-service=mountd --add-service=nfs --add-service=rpc-bind --add-service=ssh --add-service=tftp --permanent
    firewall-cmd --reload
}

function disable_nm_dnsmasq(){
    echo ">> Disabling NetworkManager's dnsmasq"
    echo "[main]
dns=none" > /etc/NetworkManager/conf.d/00-no-dnsmasq.conf

    export hostname=$(hostname -f)
    echo ">>>> Configuring Dispatcher"
    cat <<EOF >/etc/NetworkManager/dispatcher.d/00-forcedns.sh
#!/bin/bash

echo "
search alklabs.local test-ci.alklabs.local spoke0-cluster.alklabs.local
nameserver 127.0.0.1
options edns0 trust-ad
" > /run/NetworkManager/resolv.conf

export IP="$(hostname -I | cut -f1 -d\ )"
export BASE_RESOLV_CONF=/run/NetworkManager/resolv.conf
if [ "\$2" = "dhcp4-change" ] || [ "\$2" = "dhcp6-change" ] || [ "\$2" = "up" ] || [ "\$2" = "connectivity-change" ]; then
    if ! grep -q "\$IP" /etc/resolv.conf; then
      export TMP_FILE=\$(mktemp /etc/forcedns_resolv.conf.XXXXXX)
      cp  \$BASE_RESOLV_CONF \$TMP_FILE
      chmod --reference=\$BASE_RESOLV_CONF \$TMP_FILE
      sed -i -e "s/$hostname//" \
      -e "s/search /& $hostname /" \
      -e "0,/nameserver/s/nameserver/& \$IP\n&/" \$TMP_FILE
      mv \$TMP_FILE /etc/resolv.conf
    fi
fi
EOF
    chmod 755 /etc/NetworkManager/dispatcher.d/00-forcedns.sh
    chmod 644 /etc/resolv.conf

    echo ">>>> Configuring IPTables"
    iptables -C FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24 2&>1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule..."
        iptables -I FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24
        firewall-cmd --reload
    fi

    iptables -C FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24 2&>1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule..."
        iptables -I FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24
        firewall-cmd --reload
    fi 

    echo ">>>> Prunning /etc/hosts"
    echo "127.0.0.1 localhost.localdomain localhost" > /etc/hosts
}

function set_dnsmasq(){
    echo ">> Configuring dnsmasq"
    echo "user=dnsmasq
group=dnsmasq
except-interface=ztpfw,bare-net,virbr0
bind-interfaces
strict-order
bogus-priv
dhcp-authoritative
conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig" > /etc/dnsmasq.conf

    echo "domain=test-ci.alklabs.local,192.168.150.0/24,local
resolv-file=/etc/resolv.upstream.conf
# Hub Cluster
address=/.apps.test-ci.alklabs.local/192.168.150.252
address=/api.test-ci.alklabs.local/192.168.150.253
address=/api-int.test-ci.alklabs.local/192.168.150.253
# Spoke Cluster
address=/.apps.test-ci.alklabs.local/192.168.150.200
address=/api.test-ci.alklabs.local/192.168.150.201
address=/api-int.test-ci.alklabs.local/192.168.150.201" > /etc/dnsmasq.d/00-test-ci.conf

    echo "nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.upstream.conf
}

function restart_services(){
    echo ">> Restarting Services"
    systemctl restart NetworkManager
    systemctl enable --now dnsmasq
    systemctl restart libvirtd
    systemctl restart sushy
}

function checks() {
    echo 
    local fail=0
    local success=0
    echo ">> DNS Checks"
    echo ">>>> Checking External resolution"
    for interface in $(hostname -I)
    do
        echo -n "== Interface ${interface}: "
        dig +short @${interface} quay.io | grep -v -e '^$'
        if [[ $? == 0 ]];then
                let success++
        else
                echo "Failed!"
                let fail++
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
set_dnsmasq
restart_services
checks