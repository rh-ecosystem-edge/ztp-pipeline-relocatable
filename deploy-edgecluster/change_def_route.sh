#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

while true; do
  sleep 120
  ip route add default dev ${1} metric 99 >/dev/null 2>&1
done
