#!/usr/bin/env bash

source lab-dns-common.sh



function disable_nm_dnsmasq(){
    echo ">> Disabling NetworkManager's dnsmasq"
    echo "[main]
dns=none" > /etc/NetworkManager/conf.d/00-no-dnsmasq.conf

    export hostname=$(hostname -f)
    echo ">>>> Configuring Dispatcher"
    cat <<EOF >/etc/NetworkManager/dispatcher.d/00-forcedns.sh
#!/bin/bash

echo "
search factory.local test-ci.factory.local edgecluster0-cluster.factory.local
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
    iptables -C FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24 2>&1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule..."
        iptables -I FORWARD -j ACCEPT -i ztpfw -o bare-net -s 192.168.7.0/24 -d 192.168.150.0/24
        firewall-cmd --reload
    fi

    iptables -C FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24 2>&1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Adding Rule..."
        iptables -I FORWARD -j ACCEPT -i bare-net -o ztpfw -s 192.168.150.0/24 -d 192.168.7.0/24
        firewall-cmd --reload
    fi 

    echo ">>>> Prunning /etc/hosts"
    echo "127.0.0.1 localhost.localdomain localhost" > /etc/hosts
}

function set_dnsmasqconf(){
    echo ">> Configuring dnsmasq.conf"
    echo "user=dnsmasq
group=dnsmasq
except-interface=ztpfw,bare-net,virbr0
bind-interfaces
strict-order
bogus-priv
dhcp-authoritative
conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig" > /etc/dnsmasq.conf
}

function restart_services(){
    echo ">> Restarting Services"
    systemctl restart NetworkManager
    systemctl enable --now dnsmasq
    systemctl restart libvirtd
    systemctl restart sushy
}

set_firewall
disable_nm_dnsmasq
set_dnsmasqconf
set_dnsmasq /etc/dnsmasq.d/00-test-ci.conf
restart_services
checks
