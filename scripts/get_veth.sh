#!/bin/bash
set -o pipefail
set +e

if [ -z "$1" ]; then
    echo "Container ID must be specified"
fi

GRAVITY_BASH="gravity planet enter -- --notty /usr/bin/bash -- -c"
INDEX=$($GRAVITY_BASH "docker exec $1 /bin/bash -c 'cat /sys/class/net/eth0/iflink'")
# VETH=$(ip link | grep ^$INDEX | cut -d ":" -f2 | cut -d "@" -f1)

VETH=$(ip link)
VETH=$(echo $VETH | grep ^$INDEX)
VETH=$(echo $VETH | cut -d ":" -f2)
VETH=$(echo $VETH | cut -d "@" -f1)

echo ${VETH//[[:blank:]]/}
