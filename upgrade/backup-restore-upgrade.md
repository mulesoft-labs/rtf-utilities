# Backup, Restore and Upgrade Lab

## Create a test RTF with the old appliance version

1. Create an RTF in the Anypoint console
2. Script file: `rtf-install-scripts-20200728-136beef.zip`
3. Appliance version: [`1.1.1588363273-4110aff`](https://docs.mulesoft.com/release-notes/runtime-fabric/runtime-fabric-installer-release-notes#1-1-1588363273-4110aff-may-4-2020)

Set the terraform var file `myvar.tfvars` as below

```bash
cluster_name = "rtf-test"
key_pair = "mykey"
workers = 2
controllers = 1
activation_data = "xxxxxx"
anypoint_region = "ap-southeast-2"
enable_public_ips = "true"
enable_elastic_ips = "true"

#https://help.mulesoft.com/s/article/How-to-download-previous-versions-of-the-Anypoint-Runtime-Fabric-installer
installer_url = "https://runtime-fabric.s3.amazonaws.com/installer/runtime-fabric-1.1.1588363273-4110aff.tar.gz"

```
Note you need to make up the `intaller_url` per [How to download previous versions of the Anypoint Runtime Fabric installer](https://help.mulesoft.com/s/article/How-to-download-previous-versions-of-the-Anypoint-Runtime-Fabric-installer)

Run the `terraform apply` command to create the cluster

```bash
terraform apply -var-file=./myvar.tfvars -state=tf-data/myvar.tfstate
```


## Configure the RTF

1. Associate environment
2. Apply the license
```bash
# /opt/anypoint/runtimefabric/rtfctl apply mule-license "2+W..."
```
3. Enable Inbound Traffic 
4. Deploy Applications


## Create the backup cluster

Create a new RTF cluster but do not create a new RTF in the Anypoint Console. We use the same variables but no `activation_data`. 

```
cluster_name = "rtf-test-dr"
key_pair = "mykey""
workers = 2
controllers = 1
anypoint_region = "ap-southeast-2"
enable_public_ips = "true"
enable_elastic_ips = "true"

#https://help.mulesoft.com/s/article/How-to-download-previous-versions-of-the-Anypoint-Runtime-Fabric-installer
installer_url = "https://runtime-fabric.s3.amazonaws.com/installer/runtime-fabric-1.1.1588363273-4110aff.tar.gz"
```

Also, comment the steps to install RTF components from line #950
```bash
# RTF Setup
if [ "$RTF_INSTALL_ROLE" == "leader" ]; then
    run_step verify_outbound_connectivity "Outbound network check"
    # run_step install_rtf_components "Install RTF components"
    # run_step install_mule_license "Install Mule license"
    # run_step wait_for_connectivity "Wait for connectivity"
fi
``` 

This will create a new cluster without pairing up with the console plane. 

## Backup the test cluster

Run the `rtfctl backup` command on the test cluster and transfer the file to the backup cluster

```bash
[root@ip-172-31-0-231 ~]#/opt/anypoint/runtimefabric/rtfctl backup /home/ec2-user/rtf-state.tar.gz
Backing up now. This may take several minutes...
Created Pod "backup-3fac57-b9krm" in namespace "kube-system".

Container "hook" created, the current state is "waiting, reason PodInitializing".

Pod "backup-3fac57-b9krm" in namespace "kube-system", has changed state from "Pending" to "Running".
Container "hook" changed status from "waiting, reason PodInitializing" to "running".

Backing up cluster-wide resources...
Backing up namespace 2abc2ce6-cce6-463b-afaa-a1979e3ffd29...
Backing up namespace rtf...
Post-processing...
2abc2ce6-cce6-463b-afaa-a1979e3ffd29.yaml
__cluster.yaml
rtf.yaml
Done.
Pod "backup-3fac57-b9krm" in namespace "kube-system", has changed state from "Running" to "Succeeded".
Container "hook" changed status from "running" to "terminated, exit code 0".

<unknown> has completed, 9 seconds elapsed.

[root@ip-172-31-0-231 ~]#ls /home/ec2-user/rtf-state.tar.gz -al
-rw-r--r--. 1 root root 157979 Aug 24 05:06 /home/ec2-user/rtf-state.tar.gz

```

## Disconnect the test cluster from the control plane

```bash
[root@ip-172-31-0-231 ~]# kubectl scale deploy/agent -n rtf --replicas=0
deployment.extensions/agent scaled

[root@ip-172-31-0-231 ~]# kubectl get po -nrtf
NAME                                      READY   STATUS      RESTARTS   AGE
am-log-forwarder-hbtnm                    1/1     Running     0          38m
am-log-forwarder-x76nt                    1/1     Running     0          38m
cluster-status-1598246100-7thh7           0/1     Completed   0          2m11s
ingress-k6jrz                             1/1     Running     0          27m
initial-cluster-status-s4lt2              0/1     Completed   0          38m
mule-clusterip-service-657ddfc9f6-sx4cd   1/1     Running     0          38m
resource-cache-6d7f668766-q78wp           2/2     Running     0          38m
rtf-install-job-hf48p                     0/1     Completed   0          39m

```

The cluster will show `Disconnected` from the console, but the applications are still running.

```bash
[root@ip-172-31-0-231 ~]# kubectl get pod -n 2abc2ce6-cce6-463b-afaa-a1979e3ffd29
NAME                      READY   STATUS    RESTARTS   AGE
demo-app-8f7cbdfd-htrhr   2/2     Running   0          40m
demo-app-8f7cbdfd-nhdgb   2/2     Running   0          40m
```

## Restore to the backup cluster

Restore with the `rtfctl restore` command 

```bash

[root@ip-172-31-0-199 ec2-user]# /opt/anypoint/runtimefabric/rtfctl restore /home/ec2-user/rtf-state.tar.gz
WARN[0000] Warning: Failed to get agent version: configmaps "app-config" not found
Restoring now. This may take several minutes...
Created Pod "restore-af9fcd-hxjl9" in namespace "kube-system".
Container "hook" created, the current state is "waiting, reason PodInitializing".

Pod "restore-af9fcd-hxjl9" in namespace "kube-system", has changed state from "Pending" to "Running".
Container "hook" changed status from "waiting, reason PodInitializing" to "running".

Error: release: "runtime-fabric" not found
namespace "rtf" deleted
namespace/rtf created
namespace/2abc2ce6-cce6-463b-afaa-a1979e3ffd29 created
podsecuritypolicy.extensions/am-log-forwarder-psp created
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
podsecuritypolicy.extensions/coredns configured
podsecuritypolicy.extensions/external-log-forwarder-psp created
podsecuritypolicy.extensions/nethealth configured
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
podsecuritypolicy.extensions/privileged configured
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
podsecuritypolicy.extensions/restricted configured
podsecuritypolicy.extensions/rtf-install created
podsecuritypolicy.extensions/rtf-resource-cache created
podsecuritypolicy.extensions/rtf-restricted created
podsecuritypolicy.extensions/sf-edge created
clusterrole.rbac.authorization.k8s.io/am-log-forwarder created
clusterrole.rbac.authorization.k8s.io/rtf-restricted created
clusterrole.rbac.authorization.k8s.io/rtf:agent created
clusterrole.rbac.authorization.k8s.io/rtf:certificate-renewal created
clusterrole.rbac.authorization.k8s.io/rtf:cluster-status created
clusterrole.rbac.authorization.k8s.io/rtf:mule-clusterip-service created
clusterrole.rbac.authorization.k8s.io/rtf:registry-creds created
clusterrole.rbac.authorization.k8s.io/sf-edge-user created
clusterrolebinding.rbac.authorization.k8s.io/am-log-forwarder created
clusterrolebinding.rbac.authorization.k8s.io/cluster-status created
clusterrolebinding.rbac.authorization.k8s.io/edge-clusterrole-binding created
clusterrolebinding.rbac.authorization.k8s.io/rtf-default-binding created
clusterrolebinding.rbac.authorization.k8s.io/rtf:agent created
clusterrolebinding.rbac.authorization.k8s.io/rtf:certificate-renewal created
clusterrolebinding.rbac.authorization.k8s.io/rtf:mule-clusterip-service created
clusterrolebinding.rbac.authorization.k8s.io/rtf:registry-creds created
configmap/runtime-fabric.v1 created
configmap/backup-script-default configured
configmap/backup-script created
clusterrolebinding.rbac.authorization.k8s.io/tiller created
serviceaccount/rtf-tiller created
configmap/restore-data created
Restoring namespace "2abc2ce6-cce6-463b-afaa-a1979e3ffd29"...
secret/custom-properties created
secret/rtf-monitoring-certificate created
secret/rtf-muleruntime-license created
secret/rtf-pull-secret created
serviceaccount/rtf-restricted created
service/demo-app created
deployment.extensions/demo-app created
ingress.extensions/demo-app created
rolebinding.rbac.authorization.k8s.io/rtf-restricted created
Restoring namespace "rtf"...
secret/agent-keystore created
secret/custom-properties created
secret/eebf03bee257c6da1cd8f6efd3eda0a8 created
secret/install-properties created
secret/registry-creds created
secret/rtf-monitoring-certificate created
secret/rtf-muleruntime-license created
secret/rtf-pull-secret created
serviceaccount/am-log-forwarder created
serviceaccount/cluster-status created
serviceaccount/external-log-forwarder created
serviceaccount/mule-clusterip-service created
serviceaccount/registry-creds created
serviceaccount/resource-cache created
serviceaccount/rtf-agent created
serviceaccount/rtf-certificate-renewal created
serviceaccount/rtf-install created
serviceaccount/sf-edge created
configmap/1cf3e5ca4a8791da0b832918db7e9436 created
configmap/app-config created
configmap/cluster-status-output created
configmap/resource-cache-config created
configmap/resource-versions created
service/deployer created
service/metrics created
service/mule-clusterip-service created
service/resource-cache created
cronjob.batch/certificate-renewal created
cronjob.batch/cluster-status created
cronjob.batch/registry-creds created
daemonset.extensions/am-log-forwarder created
daemonset.extensions/external-log-forwarder created
daemonset.extensions/ingress created
deployment.extensions/agent created
deployment.extensions/deployer created
deployment.extensions/mule-clusterip-service created
deployment.extensions/resource-cache created
role.rbac.authorization.k8s.io/am-log-forwarder created
role.rbac.authorization.k8s.io/external-log-forwarder created
role.rbac.authorization.k8s.io/rtf:resource-cache created
rolebinding.rbac.authorization.k8s.io/am-log-forwarder created
rolebinding.rbac.authorization.k8s.io/external-log-forwarder created
rolebinding.rbac.authorization.k8s.io/rtf:resource-cache created
Refreshing registry credentials...
Error from server (NotFound): jobs.batch "refresh-registry-creds" not found
job.batch/refresh-registry-creds created
Done.
Pod "restore-af9fcd-hxjl9" in namespace "kube-system", has changed state from "Running" to "Succeeded".
Container "hook" changed status from "running" to "terminated, exit code 0".
```

The backup cluster will pair up with control plane with all the applications running. The restore process will take time depending on how many applications as it needs to download the application artifacts. 

```bash
[root@ip-172-31-0-199 ec2-user]# kubectl get pod -n 2abc2ce6-cce6-463b-afaa-a1979e3ffd29
NAME                      READY   STATUS    RESTARTS   AGE
demo-app-8f7cbdfd-s4f5p   2/2     Running   0          6m31s
demo-app-8f7cbdfd-wjn7t   2/2     Running   0          6m31s
```


## Upgrade the test cluster


```bash
[root@ip-172-31-0-231 ~]# /opt/anypoint/runtimefabric/rtfctl appliance upgrade --url https://runtime-fabric.s3.amazonaws.com/installer/runtime-fabric-1.1.1597283557-2e1fc6a.tar.gz
```


## Back up from the backup cluster and restore to the test cluster

1. Run a `rtfctl backup` from the backup cluster
```bash
[root@ip-172-31-0-199 ec2-user]# /opt/anypoint/runtimefabric/rtfctl backup /home/ec2-user/rtf-state.tar.gz
```
2. Transfer the file to the test cluster
3. Disconnect the backup from the control plane
```bash
[root@ip-172-31-0-199 ec2-user]# kubectl scale deploy/agent -n rtf --replicas=0
deployment.extensions/agent scaled
```

4. Restore on the test cluster 
```bash
[root@ip-172-31-0-231 runtimefabric]# /opt/anypoint/runtimefabric/rtfctl restore /home/ec2-user/rtf-state.tar.gz
```

This `PriorityClass1` is missing in the backup file. Create it manually. 

```bash
[root@ip-172-31-0-231 runtimefabric]# kubectl apply -f - << EOF
apiVersion: scheduling.k8s.io/v1beta1
description: Priority class used by rtf components.
kind: PriorityClass
metadata:
  creationTimestamp: null
  generation: 1
  name: rtf-components-high-priority
  selfLink: /apis/scheduling.k8s.io/v1beta1/priorityclasses/rtf-components-high-priority
value: 2000000
EOF
priorityclass.scheduling.k8s.io/rtf-components-high-priority created

```


