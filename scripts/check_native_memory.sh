#!/bin/bash

if [ -z "$1" ]; then
    echo "Please specify the application name"
    exit
fi

PODS_IP=$(kubectl get po --all-namespaces -lapp=$1 -ojsonpath='{.items[*].status.podIP}')

for POD in $PODS_IP
do 
  echo "============From POD $POD============"
  curl -sS http://$POD:7777/mule/rtf/support/diagnostics/vmNativeMemory
done