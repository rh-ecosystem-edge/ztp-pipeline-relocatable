#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

ip link set dev veth2 1>/dev/null 2>&1
sleep 5
ip link set dev veth1 1>/dev/null 2>&1
