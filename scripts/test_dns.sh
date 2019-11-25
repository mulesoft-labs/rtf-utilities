#!/bin/bash


echo "testing DNS domain $1"
IP=$(kubectl get po -n kube-system -l 'k8s-app in (kube-dns, kube-dns-worker)'  -o jsonpath='{.items[*].status.podIP}')

for ip in $IP
do
   echo "testing DNS POD $ip"
   dig $1 @$ip +short
done