#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'


# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

function ping_test() {
  ping -c1 -W 2 $1 &>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "Ping the pod $1 on $2 from $CUR_IP [${GREEN}Ok${NC}]"
    return 0
  else
    echo -e "Ping the pod $1 on $2 from $CUR_IP [${RED}Failed${NC}]"
    return 1
  fi
}

# Set GRAVITY_BASH per gravity version
GRAVITY_VERSION=$(gravity version | grep "^Version:" | awk '{ print $2 }')
vercomp $GRAVITY_VERSION "5.5.40"
if [[ $? == "1" ]]; then 
  GRAVITY_BASH="gravity planet enter -- --notty /bin/bash -- -c"
else
  GRAVITY_BASH="gravity planet enter -- --notty /usr/bin/bash -- -c"
fi



CUR_IP=$(ip route get 1 | awk '{print $NF;exit}')

# Get the node IPs
NODE_IPS=$(kubectl get nodes -o jsonpath={.items[*].status.addresses[?\(@.type==\"InternalIP\"\)].address})

echo "Testing ping on the node $CUR_IP"
for NODE_IP in $NODE_IPS
  do
    if [ $NODE_IP != $CUR_IP ]; then
      POD_IPS=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_IP,status.phase=Running -o jsonpath={.items[*].status.podIP})

      for POD_IP in $POD_IPS
        do
          if [ $POD_IP != $NODE_IP ]; then
            ping_test $POD_IP $NODE_IP
            # Only test one IP
            if [ $? -eq 0 ]; then
              break
            fi
          fi
        done
    fi
  done


echo "Checking routes on the node $CUR_IP"
SUBNETS=$($GRAVITY_BASH "etcdctl ls /coreos.com/network/subnets/" | cut -d "/" -f5 | cut -d "-" -f1)
for SUBNET in $SUBNETS
do
  if ip route | grep "$SUBNET" > /dev/null; then
    echo -e "Route to $SUBNET [${GREEN}Exists${NC}]"
  else
    echo -e "Route to $SUBNET [${RED}Missing${NC}]"
  fi
done


echo "Checking the MAC address"
SUBNETS=$($GRAVITY_BASH "etcdctl ls /coreos.com/network/subnets/")
for SUBNET in $SUBNETS
do 
  MAC=$($GRAVITY_BASH "etcdctl get $SUBNET | jq -r '.BackendData.VtepMAC'")
  NODE_IP=$($GRAVITY_BASH "etcdctl get $SUBNET | jq -r '.PublicIP'")
  FLANNEL_IP=$(echo $SUBNET | cut -d "/" -f5 | cut -d "-" -f1)

  if [ $NODE_IP != $CUR_IP ]; then
    if arp -n | grep $FLANNEL_IP | grep $MAC > /dev/null ; then
      echo -e "MAC $MAC ($NODE_IP) [${GREEN}Matches${NC}]"
    else
      echo -e "MAC $MAC ($NODE_IP) [${RED}Doesn't match${NC}]"
    fi
  fi
done

