#!/bin/bash

GRAVITY_BASH="gravity planet enter -- --notty /usr/bin/bash -- -c"
INDEX=$($GRAVITY_BASH "docker exec $1 /bin/bash -c 'cat /sys/class/net/eth0/iflink'")
VETH=$(ip link | grep ^$INDEX | cut -d ":" -f2 | cut -d "@" -f1)
echo ${VETH//[[:blank:]]/}