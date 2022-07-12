#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

nmcli con up veth2 1>/dev/null 2>&1
nmcli con up veth1 1>/dev/null 2>&1
