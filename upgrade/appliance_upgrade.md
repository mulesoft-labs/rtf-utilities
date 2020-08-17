# Appliance upgrade

## Appliance upgrade process in general

1. Preparation. Deploy agents, run prechecks and bootstrap
2. Upgrade gravity on the leader node
  * Stepdown the leader node. Make another node the leader
  * Drain pods on the node
  * Upgrade gravity
  * taint
  * uncordon
  * endpoints
  * untaint
3. Elect the node in 2 to be a leader 
4. Upgrade other nodes
  * Drain pods
  * Upgrade gravity
  * taint
  * uncordon
  * endpoints
  * untaint
  * Enable leader election on a node if it's a controller
5. Upgrade k8s Runtime components. Usually creates an upgrade pod to finish the upgrade 
6. Config or ETCD upgrades
7. Runtime-fabric app
8. GC

## Upgrade logs
1. `/var/log/gravity-system` from the node where you run the upgrade records the most logs
2. `/var/log/gravity-system` from the node where the phase is executed
3. Outputs with `--debug` from the node where the plan is executed
4. The component logs from the node where the plan is executed
5. The logs from `<phase>-upgrade-xxx` pod if it's in the runtime upgrade phase

## What's behind `rtfctl appliance upgrade`

The `rtfctl appliance upgrade` wraps up a couple of commands, for example. 

`rtfctl appliance upgrade --url https://runtime-fabric.s3.amazonaws.com/installer/runtime-fabric-1.1.1591285019-e135da0.tar.gz` 

The command is an equivalent of the set of commands as below:

```bash
# download package
$ cd /opt/anypoint/runtimefabric/
$ curl https://runtime-fabric.s3.amazonaws.com/installer/runtime-fabric-1.1.1591285019-e135da0.tar.gz -o runtime-fabric-1.1.1591285019-e135da0.tar.gz

# unzip
$ rm -rf ./installer/*
$ tar -zxvf runtime-fabric-1.1.1572976203-3ad8a93.tar.gz -C ./installer
$ cd installer

# upload packages to gravity-site
$ ./upload

# upgrade
$ ./gravity upgrade
```
## Upgrade process in details
(from 1.1.1581474166-1f657f1 to 1.1.1583954392-3121bcd)

After the package is unzipped. Check the installer folder
```bash
$ cd installer
$ ls
app.yaml  gravity  gravity.db  install  packages  README  run_preflight_checks  scripts  upgrade  upload
```

Check the packages before uploading.

```bash

gravity package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009 --insecure

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.36 99MB
* gravitational.io/gravity:5.5.38 100MB
* gravitational.io/kubernetes:5.5.36 5.6MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.7 300MB
* gravitational.io/planet:5.5.33-11312 473MB purpose:runtime
* gravitational.io/rbac-app:5.5.36 5.6MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/runtime-fabric:1.1.1581474166-1f657f1 234MB
* gravitational.io/site:5.5.36 91MB
* gravitational.io/teleport:3.0.5 32MB
* gravitational.io/tiller-app:5.5.2 31MB
* gravitational.io/web-assets:5.5.36 1.2MB

[rtf-1.1.1581474166]
--------------------

* rtf-1.1.1581474166/cert-authority:0.0.1 12kB operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:ca
* rtf-1.1.1581474166/planet-172.31.0.106-secrets:5.5.33-11312 52kB operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:planet-secrets,advertise-ip:172.31.0.106
* rtf-1.1.1581474166/planet-172.31.0.155-secrets:5.5.33-11312 35kB advertise-ip:172.31.0.155,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:planet-secrets
* rtf-1.1.1581474166/planet-172.31.1.251-secrets:5.5.33-11312 52kB purpose:planet-secrets,advertise-ip:172.31.1.251,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172
* rtf-1.1.1581474166/planet-172.31.1.37-secrets:5.5.33-11312 35kB operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:planet-secrets,advertise-ip:172.31.1.37
* rtf-1.1.1581474166/planet-172.31.2.11-secrets:5.5.33-11312 52kB advertise-ip:172.31.2.11,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:planet-secrets
* rtf-1.1.1581474166/planet-config-172310106rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.0.106,config-package-for:gravitational.io/planet:0.0.0,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:planet-config
* rtf-1.1.1581474166/planet-config-172310155rtf-111581474166:5.5.33-11312 4.6kB config-package-for:gravitational.io/planet:0.0.0,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:planet-config,advertise-ip:172.31.0.155
* rtf-1.1.1581474166/planet-config-172311251rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.1.251,config-package-for:gravitational.io/planet:0.0.0,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:planet-config
* rtf-1.1.1581474166/planet-config-17231137rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.1.37,config-package-for:gravitational.io/planet:0.0.0,operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:planet-config
* rtf-1.1.1581474166/planet-config-17231211rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.2.11,config-package-for:gravitational.io/planet:0.0.0,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:planet-config
* rtf-1.1.1581474166/rpcagent-secrets:5.5.38 12kB purpose:rpc-secrets
* rtf-1.1.1581474166/teleport-master-config-172310106rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.106,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:teleport-master-config
* rtf-1.1.1581474166/teleport-master-config-172311251rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.1.251,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:teleport-master-config
* rtf-1.1.1581474166/teleport-master-config-17231211rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.2.11,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:teleport-master-config
* rtf-1.1.1581474166/teleport-node-config-172310106rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.106,config-package-for:gravitational.io/teleport:0.0.0,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-172310155rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.155,config-package-for:gravitational.io/teleport:0.0.0,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-172311251rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.1.251,config-package-for:gravitational.io/teleport:0.0.0,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-17231137rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.1.37,config-package-for:gravitational.io/teleport:0.0.0,operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-17231211rtf-111581474166:3.0.5 4.1kB operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:teleport-node-config,advertise-ip:172.31.2.11,config-package-for:gravitational.io/teleport:0.0.0
```

Upload to the packages to the gravity-site store, which is accessible to other nodes
```bash
 ./upload
Sun Jun  7 14:40:08 UTC Importing cluster image runtime-fabric v1.1.1583954392-3121bcd
Sun Jun  7 14:41:15 UTC Synchronizing application with Docker registry 172.31.0.106:5000
Sun Jun  7 14:41:34 UTC Synchronizing application with Docker registry 172.31.1.251:5000
Sun Jun  7 14:41:52 UTC Synchronizing application with Docker registry 172.31.2.11:5000
Sun Jun  7 14:42:11 UTC Cluster image has been uploaded
```

Recheck the gravity store. The artifacts of the new components are uploaded. 

```bash
gravity package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009 --insecure

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.36 99MB
* gravitational.io/gravity:5.5.38 100MB
* gravitational.io/kubernetes:5.5.36 5.6MB
* gravitational.io/kubernetes:5.5.38 5.3MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.11 258MB
* gravitational.io/monitoring-app:5.5.7 300MB
* gravitational.io/planet:5.5.33-11312 473MB purpose:runtime
* gravitational.io/planet:5.5.35-11312 475MB
* gravitational.io/rbac-app:5.5.36 5.6MB
* gravitational.io/rbac-app:5.5.38 5.3MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/runtime-fabric:1.1.1581474166-1f657f1 234MB
* gravitational.io/runtime-fabric:1.1.1583954392-3121bcd 229MB
* gravitational.io/site:5.5.36 91MB
* gravitational.io/site:5.5.38 91MB
* gravitational.io/teleport:3.0.5 32MB
* gravitational.io/tiller-app:5.5.2 31MB
* gravitational.io/web-assets:5.5.36 1.2MB
* gravitational.io/web-assets:5.5.38 1.2MB

[rtf-1.1.1581474166]
--------------------

* rtf-1.1.1581474166/cert-authority:0.0.1 12kB operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:ca
* rtf-1.1.1581474166/planet-172.31.0.106-secrets:5.5.33-11312 52kB advertise-ip:172.31.0.106,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:planet-secrets
* rtf-1.1.1581474166/planet-172.31.0.155-secrets:5.5.33-11312 35kB advertise-ip:172.31.0.155,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:planet-secrets
* rtf-1.1.1581474166/planet-172.31.1.251-secrets:5.5.33-11312 52kB advertise-ip:172.31.1.251,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:planet-secrets
* rtf-1.1.1581474166/planet-172.31.1.37-secrets:5.5.33-11312 35kB advertise-ip:172.31.1.37,operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:planet-secrets
* rtf-1.1.1581474166/planet-172.31.2.11-secrets:5.5.33-11312 52kB purpose:planet-secrets,advertise-ip:172.31.2.11,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d
* rtf-1.1.1581474166/planet-config-172310106rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.0.106,config-package-for:gravitational.io/planet:0.0.0,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:planet-config
* rtf-1.1.1581474166/planet-config-172310155rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.0.155,config-package-for:gravitational.io/planet:0.0.0,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:planet-config
* rtf-1.1.1581474166/planet-config-172311251rtf-111581474166:5.5.33-11312 4.6kB config-package-for:gravitational.io/planet:0.0.0,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:planet-config,advertise-ip:172.31.1.251
* rtf-1.1.1581474166/planet-config-17231137rtf-111581474166:5.5.33-11312 4.6kB advertise-ip:172.31.1.37,config-package-for:gravitational.io/planet:0.0.0,operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:planet-config
* rtf-1.1.1581474166/planet-config-17231211rtf-111581474166:5.5.33-11312 4.6kB operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:planet-config,advertise-ip:172.31.2.11,config-package-for:gravitational.io/planet:0.0.0
* rtf-1.1.1581474166/rpcagent-secrets:5.5.38 12kB purpose:rpc-secrets
* rtf-1.1.1581474166/teleport-master-config-172310106rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.106,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:teleport-master-config
* rtf-1.1.1581474166/teleport-master-config-172311251rtf-111581474166:3.0.5 4.1kB operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:teleport-master-config,advertise-ip:172.31.1.251
* rtf-1.1.1581474166/teleport-master-config-17231211rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.2.11,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d,purpose:teleport-master-config
* rtf-1.1.1581474166/teleport-node-config-172310106rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.106,config-package-for:gravitational.io/teleport:0.0.0,operation-id:33cb045d-15d0-42fc-8352-7960245cd8de,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-172310155rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.0.155,config-package-for:gravitational.io/teleport:0.0.0,operation-id:0d745454-295f-4973-9022-ce812f31955c,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-172311251rtf-111581474166:3.0.5 4.1kB config-package-for:gravitational.io/teleport:0.0.0,operation-id:757be834-b7b2-4e58-a2b9-acfc3004a172,purpose:teleport-node-config,advertise-ip:172.31.1.251
* rtf-1.1.1581474166/teleport-node-config-17231137rtf-111581474166:3.0.5 4.1kB advertise-ip:172.31.1.37,config-package-for:gravitational.io/teleport:0.0.0,operation-id:16d133ac-b832-42cf-b998-cde61a3aa1f2,purpose:teleport-node-config
* rtf-1.1.1581474166/teleport-node-config-17231211rtf-111581474166:3.0.5 4.1kB purpose:teleport-node-config,advertise-ip:172.31.2.11,config-package-for:gravitational.io/teleport:0.0.0,operation-id:602578c1-d7ec-488b-a186-f84bf4f2ea8d
```

Note you can upload multiple packages. The upgrade job always picks up the latest. In some cases, if you want to remove a package from the gravity-site store. Run the `delete` command

```bash
To remove from the cluster storages (has to be done once):

gravity package delete <package-name> -ops-url=https://gravity-site.kube-system.svc.cluster.local:3009 -insecure
```

Deploy agent. These agents will execute the upgrading job for each node.

```bash
$ ./gravity upgrade -m
Sun Jun  7 14:58:17 UTC Upgrading cluster from 1.1.1581474166-1f657f1 to 1.1.1583954392-3121bcd
Sun Jun  7 14:58:19 UTC Deploying agents on cluster nodes
Sun Jun  7 14:58:24 UTC Deployed agent on ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37)
Sun Jun  7 14:58:24 UTC Deployed agent on ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37)
Sun Jun  7 14:58:24 UTC Deployed agent on ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37)
Sun Jun  7 14:58:24 UTC Deployed agent on ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37)
Sun Jun  7 14:58:24 UTC Deployed agent on ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37)
The operation has been created in manual mode.

See https://gravitational.com/gravity/docs/cluster/#managing-an-ongoing-operation for details on working with operation plan.
```

We can see agent logs in `/var/log/messages`

```bash
$ tail -f /var/log/messages
...
Jun  7 14:58:21 ip-172-31-1-251 gravity: INFO [NODE]      [LOCAL EXEC] Started command: "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/writable/bin gravity enter -- --notty /usr/bin/gravity -- package export --file-mask=755 gravitational.io/gravity:5.5.38 /var/lib/gravity/site/update/agent/gravity --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009 --insecure" id:29 local:172.31.1.251:3022 login:root remote:127.0.0.1:36960 teleportUser:opscenter@gravitational.io srv/exec.go:171

Jun  7 14:58:24 ip-172-31-1-251 gravity: INFO [NODE]      [LOCAL EXEC] Started command: "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/writable/bin /var/lib/gravity/site/update/agent/gravity agent --debug install sync-plan" id:30 local:172.31.1.251:3022 login:root remote:127.0.0.1:36960 teleportUser:opscenter@gravitational.io srv/exec.go:171
```

Checking the gravity status, it's `updating`. As this operation is progressing, other new operations will not start. 

```bash
[root@ip-172-31-0-106 installer]# gravity status
Cluster name:   rtf-1.1.1581474166
Cluster status:   updating
Application:    runtime-fabric, version 1.1.1581474166-1f657f1
Gravity version:  5.5.38 (client) / 5.5.38 (server)
Join token:   bW3fK7BsYusypWG6
Periodic updates: Not Configured
Remote support:   Not Configured
Active operations:
    * operation_update (a3d168e2-52c3-43bd-8499-38718e166f89)
      started:  Sun Jun  7 14:58 UTC (1 hour ago)
      use 'gravity plan --operation-id=a3d168e2-52c3-43bd-8499-38718e166f89' to check operation status
Last completed operation:
    * operation_expand (16d133ac-b832-42cf-b998-cde61a3aa1f2)
      started:    Sat Jun  6 19:59 UTC (20 hours ago)
      completed:  Sat Jun  6 20:00 UTC (20 hours ago)
Cluster endpoints:
    * Authentication gateway:
        - 172.31.0.106:32009
        - 172.31.1.251:32009
        - 172.31.2.11:32009
    * Cluster management URL:
        - https://172.31.0.106:32009
        - https://172.31.1.251:32009
        - https://172.31.2.11:32009
Cluster nodes:
    Masters:
        * ip-172-31-0-106.ap-southeast-2.compute.internal (172.31.0.106, controller_node)
            Status: healthy
        * ip-172-31-1-251.ap-southeast-2.compute.internal (172.31.1.251, controller_node)
            Status: healthy
        * ip-172-31-2-11.ap-southeast-2.compute.internal (172.31.2.11, controller_node)
            Status: healthy
    Nodes:
        * ip-172-31-0-155.ap-southeast-2.compute.internal (172.31.0.155, worker_node)
            Status: healthy
        * ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37, worker_node)
            Status: healthy
```

Check the `gravity plan` which shows the upgrade plan. 
```bash
gravity plan
Phase                                                              Description                                                                                 State         Node             Requires                                                                                                              Updated
-----                                                              -----------                                                                                 -----         ----             --------                                                                                                              -------
* init                                                             Initialize update operation                                                                 Unstarted     -                -                                                                                                                     -
  * ip-172-31-0-106.ap-southeast-2.compute.internal                Initialize node "ip-172-31-0-106.ap-southeast-2.compute.internal"                           Unstarted     172.31.0.106     -                                                                                                                     -
  * ip-172-31-1-251.ap-southeast-2.compute.internal                Initialize node "ip-172-31-1-251.ap-southeast-2.compute.internal"                           Unstarted     172.31.1.251     -                                                                                                                     -
  * ip-172-31-0-155.ap-southeast-2.compute.internal                Initialize node "ip-172-31-0-155.ap-southeast-2.compute.internal"                           Unstarted     172.31.0.155     -                                                                                                                     -
  * ip-172-31-2-11.ap-southeast-2.compute.internal                 Initialize node "ip-172-31-2-11.ap-southeast-2.compute.internal"                            Unstarted     172.31.2.11      -                                                                                                                     -
  * ip-172-31-1-37.ap-southeast-2.compute.internal                 Initialize node "ip-172-31-1-37.ap-southeast-2.compute.internal"                            Unstarted     172.31.1.37      -                                                                                                                     -
* checks                                                           Run preflight checks                                                                        Unstarted     -                /init                                                                                                                 -
* pre-update                                                       Run pre-update application hook                                                             Unstarted     -                /init,/checks                                                                                                         -
* bootstrap                                                        Bootstrap update operation on nodes                                                         Unstarted     -                /checks,/pre-update                                                                                                   -
  * ip-172-31-0-106.ap-southeast-2.compute.internal                Bootstrap node "ip-172-31-0-106.ap-southeast-2.compute.internal"                            Unstarted     172.31.0.106     -                                                                                                                     -
  * ip-172-31-1-251.ap-southeast-2.compute.internal                Bootstrap node "ip-172-31-1-251.ap-southeast-2.compute.internal"                            Unstarted     172.31.1.251     -                                                                                                                     -
  * ip-172-31-0-155.ap-southeast-2.compute.internal                Bootstrap node "ip-172-31-0-155.ap-southeast-2.compute.internal"                            Unstarted     172.31.0.155     -                                                                                                                     -
  * ip-172-31-2-11.ap-southeast-2.compute.internal                 Bootstrap node "ip-172-31-2-11.ap-southeast-2.compute.internal"                             Unstarted     172.31.2.11      -                                                                                                                     -
  * ip-172-31-1-37.ap-southeast-2.compute.internal                 Bootstrap node "ip-172-31-1-37.ap-southeast-2.compute.internal"                             Unstarted     172.31.1.37      -                                                                                                                     -
* coredns                                                          Provision CoreDNS resources                                                                 Unstarted     -                /bootstrap                                                                                                            -
* masters                                                          Update master nodes                                                                         Unstarted     -                /coredns                                                                                                              -
  * ip-172-31-0-106.ap-southeast-2.compute.internal                Update system software on master node "ip-172-31-0-106.ap-southeast-2.compute.internal"     Unstarted     -                -                                                                                                                     -
    * kubelet-permissions                                          Add permissions to kubelet on "ip-172-31-0-106.ap-southeast-2.compute.internal"             Unstarted     -                -                                                                                                                     -
    * stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal     Step down "ip-172-31-0-106.ap-southeast-2.compute.internal" as Kubernetes leader            Unstarted     -                /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/kubelet-permissions                                          -
    * drain                                                        Drain node "ip-172-31-0-106.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal     -
    * system-upgrade                                               Update system software on node "ip-172-31-0-106.ap-southeast-2.compute.internal"            Unstarted     172.31.0.106     /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/drain                                                        -
    * taint                                                        Taint node "ip-172-31-0-106.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade                                               -
    * uncordon                                                     Uncordon node "ip-172-31-0-106.ap-southeast-2.compute.internal"                             Unstarted     172.31.0.106     /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/taint                                                        -
    * untaint                                                      Remove taint from node "ip-172-31-0-106.ap-southeast-2.compute.internal"                    Unstarted     172.31.0.106     /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/uncordon                                                     -
  * elect-ip-172-31-0-106.ap-southeast-2.compute.internal          Make node "ip-172-31-0-106.ap-southeast-2.compute.internal" Kubernetes leader               Unstarted     -                /masters/ip-172-31-0-106.ap-southeast-2.compute.internal                                                              -
  * ip-172-31-1-251.ap-southeast-2.compute.internal                Update system software on master node "ip-172-31-1-251.ap-southeast-2.compute.internal"     Unstarted     -                /masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal                                                        -
    * drain                                                        Drain node "ip-172-31-1-251.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     -                                                                                                                     -
    * system-upgrade                                               Update system software on node "ip-172-31-1-251.ap-southeast-2.compute.internal"            Unstarted     172.31.1.251     /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/drain                                                        -
    * taint                                                        Taint node "ip-172-31-1-251.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade                                               -
    * uncordon                                                     Uncordon node "ip-172-31-1-251.ap-southeast-2.compute.internal"                             Unstarted     172.31.0.106     /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/taint                                                        -
    * endpoints                                                    Wait for DNS/cluster endpoints on "ip-172-31-1-251.ap-southeast-2.compute.internal"         Unstarted     172.31.0.106     /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/uncordon                                                     -
    * untaint                                                      Remove taint from node "ip-172-31-1-251.ap-southeast-2.compute.internal"                    Unstarted     172.31.0.106     /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/endpoints                                                    -
    * enable-ip-172-31-1-251.ap-southeast-2.compute.internal       Enable leader election on node "ip-172-31-1-251.ap-southeast-2.compute.internal"            Unstarted     -                /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/untaint                                                      -
  * ip-172-31-2-11.ap-southeast-2.compute.internal                 Update system software on master node "ip-172-31-2-11.ap-southeast-2.compute.internal"      Unstarted     -                /masters/ip-172-31-1-251.ap-southeast-2.compute.internal                                                              -
    * drain                                                        Drain node "ip-172-31-2-11.ap-southeast-2.compute.internal"                                 Unstarted     172.31.0.106     -                                                                                                                     -
    * system-upgrade                                               Update system software on node "ip-172-31-2-11.ap-southeast-2.compute.internal"             Unstarted     172.31.2.11      /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/drain                                                         -
    * taint                                                        Taint node "ip-172-31-2-11.ap-southeast-2.compute.internal"                                 Unstarted     172.31.0.106     /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/system-upgrade                                                -
    * uncordon                                                     Uncordon node "ip-172-31-2-11.ap-southeast-2.compute.internal"                              Unstarted     172.31.0.106     /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/taint                                                         -
    * endpoints                                                    Wait for DNS/cluster endpoints on "ip-172-31-2-11.ap-southeast-2.compute.internal"          Unstarted     172.31.0.106     /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/uncordon                                                      -
    * untaint                                                      Remove taint from node "ip-172-31-2-11.ap-southeast-2.compute.internal"                     Unstarted     172.31.0.106     /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/endpoints                                                     -
    * enable-ip-172-31-2-11.ap-southeast-2.compute.internal        Enable leader election on node "ip-172-31-2-11.ap-southeast-2.compute.internal"             Unstarted     -                /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/untaint                                                       -
* nodes                                                            Update regular nodes                                                                        Unstarted     -                /masters                                                                                                              -
  * ip-172-31-0-155.ap-southeast-2.compute.internal                Update system software on node "ip-172-31-0-155.ap-southeast-2.compute.internal"            Unstarted     -                -                                                                                                                     -
    * drain                                                        Drain node "ip-172-31-0-155.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     -                                                                                                                     -
    * system-upgrade                                               Update system software on node "ip-172-31-0-155.ap-southeast-2.compute.internal"            Unstarted     172.31.0.155     /nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/drain                                                          -
    * taint                                                        Taint node "ip-172-31-0-155.ap-southeast-2.compute.internal"                                Unstarted     172.31.0.106     /nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade                                                 -
    * uncordon                                                     Uncordon node "ip-172-31-0-155.ap-southeast-2.compute.internal"                             Unstarted     172.31.0.106     /nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/taint                                                          -
    * endpoints                                                    Wait for DNS/cluster endpoints on "ip-172-31-0-155.ap-southeast-2.compute.internal"         Unstarted     172.31.0.106     /nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/uncordon                                                       -
    * untaint                                                      Remove taint from node "ip-172-31-0-155.ap-southeast-2.compute.internal"                    Unstarted     172.31.0.106     /nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/endpoints                                                      -
  * ip-172-31-1-37.ap-southeast-2.compute.internal                 Update system software on node "ip-172-31-1-37.ap-southeast-2.compute.internal"             Unstarted     -                -                                                                                                                     -
    * drain                                                        Drain node "ip-172-31-1-37.ap-southeast-2.compute.internal"                                 Unstarted     172.31.0.106     -                                                                                                                     -
    * system-upgrade                                               Update system software on node "ip-172-31-1-37.ap-southeast-2.compute.internal"             Unstarted     172.31.1.37      /nodes/ip-172-31-1-37.ap-southeast-2.compute.internal/drain                                                           -
    * taint                                                        Taint node "ip-172-31-1-37.ap-southeast-2.compute.internal"                                 Unstarted     172.31.0.106     /nodes/ip-172-31-1-37.ap-southeast-2.compute.internal/system-upgrade                                                  -
    * uncordon                                                     Uncordon node "ip-172-31-1-37.ap-southeast-2.compute.internal"                              Unstarted     172.31.0.106     /nodes/ip-172-31-1-37.ap-southeast-2.compute.internal/taint                                                           -
    * endpoints                                                    Wait for DNS/cluster endpoints on "ip-172-31-1-37.ap-southeast-2.compute.internal"          Unstarted     172.31.0.106     /nodes/ip-172-31-1-37.ap-southeast-2.compute.internal/uncordon                                                        -
    * untaint                                                      Remove taint from node "ip-172-31-1-37.ap-southeast-2.compute.internal"                     Unstarted     172.31.0.106     /nodes/ip-172-31-1-37.ap-southeast-2.compute.internal/endpoints                                                       -
* config                                                           Update system configuration on nodes                                                        Unstarted     -                /nodes                                                                                                                -
  * ip-172-31-0-106.ap-southeast-2.compute.internal                Update system configuration on node "ip-172-31-0-106.ap-southeast-2.compute.internal"       Unstarted     -                -                                                                                                                     -
  * ip-172-31-1-251.ap-southeast-2.compute.internal                Update system configuration on node "ip-172-31-1-251.ap-southeast-2.compute.internal"       Unstarted     -                -                                                                                                                     -
  * ip-172-31-2-11.ap-southeast-2.compute.internal                 Update system configuration on node "ip-172-31-2-11.ap-southeast-2.compute.internal"        Unstarted     -                -                                                                                                                     -
* runtime                                                          Update application runtime                                                                  Unstarted     -                /config                                                                                                               -
  * rbac-app                                                       Update system application "rbac-app" to 5.5.38                                              Unstarted     -                -                                                                                                                     -
  * monitoring-app                                                 Update system application "monitoring-app" to 5.5.11                                        Unstarted     -                /runtime/rbac-app                                                                                                     -
  * site                                                           Update system application "site" to 5.5.38                                                  Unstarted     -                /runtime/monitoring-app                                                                                               -
  * kubernetes                                                     Update system application "kubernetes" to 5.5.38                                            Unstarted     -                /runtime/site                                                                                                         -
* migration                                                        Perform system database migration                                                           Unstarted     -                /runtime                                                                                                              -
  * labels                                                         Update node labels                                                                          Unstarted     -                -                                                                                                                     -
* app                                                              Update installed application                                                                Unstarted     -                /migration                                                                                                            -
  * runtime-fabric                                                 Update application "runtime-fabric" to 1.1.1583954392-3121bcd                               Unstarted     -                -                                                                                                                     -
* gc                                                               Run cleanup tasks                                                                           Unstarted     -                /app                                                                                                                  -
  * ip-172-31-0-106.ap-southeast-2.compute.internal                Clean up node "ip-172-31-0-106.ap-southeast-2.compute.internal"                             Unstarted     -                -                                                                                                                     -
  * ip-172-31-1-251.ap-southeast-2.compute.internal                Clean up node "ip-172-31-1-251.ap-southeast-2.compute.internal"                             Unstarted     -                -                                                                                                                     -
  * ip-172-31-0-155.ap-southeast-2.compute.internal                Clean up node "ip-172-31-0-155.ap-southeast-2.compute.internal"                             Unstarted     -                -                                                                                                                     -
  * ip-172-31-2-11.ap-southeast-2.compute.internal                 Clean up node "ip-172-31-2-11.ap-southeast-2.compute.internal"                              Unstarted     -                -                                                                                                                     -
  * ip-172-31-1-37.ap-southeast-2.compute.internal                 Clean up node "ip-172-31-1-37.ap-southeast-2.compute.internal"                              Unstarted     -                -                                                                                                                     -
```

Run the firt phase `init`

```bash

./gravity plan execute --phase=/init
Sun Jun  7 15:09:06 UTC Executing "/init/ip-172-31-0-106.ap-southeast-2.compute.internal" locally
Sun Jun  7 15:09:08 UTC Executing "/init/ip-172-31-1-251.ap-southeast-2.compute.internal" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal
Sun Jun  7 15:09:10 UTC Executing "/init/ip-172-31-0-155.ap-southeast-2.compute.internal" on remote node ip-172-31-0-155.ap-southeast-2.compute.internal
Sun Jun  7 15:09:12 UTC Executing "/init/ip-172-31-2-11.ap-southeast-2.compute.internal" on remote node ip-172-31-2-11.ap-southeast-2.compute.internal
Sun Jun  7 15:09:14 UTC Executing "/init/ip-172-31-1-37.ap-southeast-2.compute.internal" on remote node ip-172-31-1-37.ap-southeast-2.compute.internal
Sun Jun  7 15:09:16 UTC Executing phase "/init" finished in 10 seconds
```
The agent on `ip-172-31-2-11` received the command and executed

```bash
$ tail -f /var/log/gravity-system.log
...
2020-06-07T15:09:12Z DEBU             request received args:[plan execute --phase /init/ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-07T15:09:13Z DEBU             completed OK args:[plan execute --phase /init/ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
...
```

The `bootstrap` phase

```bash
$ ./gravity plan execute --phase=/bootstrap
Sun Jun  7 15:16:32 UTC Executing "/bootstrap/ip-172-31-0-106.ap-southeast-2.compute.internal" locally
  Still executing "/bootstrap/ip-172-31-0-106.ap-southeast-2.compute.internal" locally (10 seconds elapsed)
Sun Jun  7 15:16:50 UTC Executing "/bootstrap/ip-172-31-1-251.ap-southeast-2.compute.internal" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal
Sun Jun  7 15:16:56 UTC Executing "/bootstrap/ip-172-31-0-155.ap-southeast-2.compute.internal" on remote node ip-172-31-0-155.ap-southeast-2.compute.internal
Sun Jun  7 15:17:02 UTC Executing "/bootstrap/ip-172-31-2-11.ap-southeast-2.compute.internal" on remote node ip-172-31-2-11.ap-southeast-2.compute.internal
Sun Jun  7 15:17:07 UTC Executing "/bootstrap/ip-172-31-1-37.ap-southeast-2.compute.internal" on remote node ip-172-31-1-37.ap-southeast-2.compute.internal
Sun Jun  7 15:17:12 UTC Executing phase "/bootstrap" finished in 40 seconds
```

The agent on `ip-172-31-2-11` received the command and executed
```bash
$ tail -f /var/log/gravity-system.log
...
2020-06-07T15:17:02Z DEBU             request received args:[plan execute --phase /bootstrap/ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-07T15:17:06Z DEBU             completed OK args:[plan execute --phase /bootstrap/ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
...
```

Take a look at the leader node. The node ip-172-31-0-106 is the leader atm. 
```bash
$ gravity enter
$ cat /etc/coredns/coredns.hosts
172.31.0.106 leader.telekube.local leader.gravity.local registry.local apiserver
```

Next the upgrade will force to elect another leader and upgrade ip-172-31-0-106
```bash
 $ ./gravity plan execute --phase=/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal --debug
 ...
 
...
2020-06-07T15:30:23Z INFO             Executing phase: /masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal. phase:/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal fsm/logger.go:55
2020-06-07T15:30:23Z DEBU             Executing command: [/opt/anypoint/runtimefabric/installer/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/rtf-1.1.1581474166/election/172.31.0.106 false]. fsm/rpc.go:217
2020-06-07T15:30:23Z INFO             Wait for new leader election. phase:/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal fsm/logger.go:55
2020-06-07T15:30:23Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/stepdown-ip-172-31-0-106.ap-southeast-2.compute.internal, State=completed) cluster/engine.go:281
...

# Check the leader node again. The leader is 172.31.1.251 now
$ gravity enter
$ cat /etc/coredns/coredns.hosts
172.31.1.251 leader.telekube.local leader.gravity.local registry.local apiserver
```

Drain the pods running on the node `ip-172-31-0-106` to other nodes

```bash
./gravity plan execute --phase=/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/drain

# Only daemon set pods left in the cluster
[root@ip-172-31-0-106 log]# kubectl get po --all-namespaces -o wide | grep 106
kube-system   coredns-5nqcz                             1/1     Running     0          19h     10.244.38.3    172.31.0.106   <none>           <none>
kube-system   gravity-site-bz784                        1/1     Running     0          19h     172.31.0.106   172.31.0.106   <none>           <none>
kube-system   log-forwarder-w86vk                       1/1     Running     0          19h     10.244.38.6    172.31.0.106   <none>           <none>
monitoring    telegraf-node-master-g7qb4                1/1     Running     0          19h     10.244.38.11   172.31.0.106   <none>           <none>

[root@ip-172-31-0-106 log]# kubectl get ds --all-namespaces
NAMESPACE     NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                                  AGE
kube-system   coredns                  3         3         3       3            3           beta.kubernetes.io/os=linux,gravitational.io/k8s-role=master   19h
kube-system   coredns-worker           2         2         2       2            2           beta.kubernetes.io/os=linux,gravitational.io/k8s-role=node     19h
kube-system   gravity-site             3         3         1       3            1           gravitational.io/k8s-role=master                               19h
kube-system   log-forwarder            5         5         5       5            5           <none>                                                         19h
monitoring    telegraf-node-master     3         3         3       3            3           gravitational.io/k8s-role=master                               19h
monitoring    telegraf-node-worker     2         2         2       2            2           gravitational.io/k8s-role=node                                 19h
rtf           am-log-forwarder         2         2         2       2            2           <none>                                                         19h
rtf           external-log-forwarder   0         0         0       0            0           rtf.mulesoft.com/externalLogForwarding=none                    19h
rtf           ingress                  0         0         0       0            0           rtf.mulesoft.com/ingress=none                                  19h

```

`system-upgrade` is the step to upgrade gravity component. You will see the gravity is upgraded after this step.  

```bash

./gravity plan execute --phase=/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade
Sun Jun  7 15:46:29 UTC Executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (10 seconds elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (20 seconds elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (30 seconds elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (40 seconds elapsed)
binary package gravitational.io/gravity:5.5.38 installed in /usr/bin/gravity
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (50 seconds elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
Sun Jun  7 15:47:59 UTC Executing phase "/masters/ip-172-31-0-106.ap-southeast-2.compute.internal/system-upgrade" finished in 1 minute


# gravity binary is upgraded 
[root@ip-172-31-0-106 installer]# gravity version
Edition:  enterprise
Version:  5.5.38
Git Commit: cba48cbe2f25b3b46628657fbdfe50e1159c34ed
Helm Version: v2.12


[root@ip-172-31-0-155 ~]# gravity version
Edition:  enterprise
Version:  5.5.36
Git Commit: d5a413f8dbbdbd2f8cb143dfe196279c4d7d8c6c
Helm Version: v2.12

```

The node `ip-172-31-0-106` is upgraded and kube-apiserver will be moved back to this node. 

```bash
$ ./gravity plan execute --phase=/masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal --debug
2020-06-07T15:53:34Z INFO             Executing phase: /masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal. phase:/masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal fsm/logger.go:55
2020-06-07T15:53:34Z DEBU             Executing command: [/opt/anypoint/runtimefabric/installer/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/rtf-1.1.1581474166/election/172.31.1.251 false]. fsm/rpc.go:217
2020-06-07T15:53:34Z DEBU             Executing command: [/opt/anypoint/runtimefabric/installer/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/rtf-1.1.1581474166/election/172.31.2.11 false]. fsm/rpc.go:217
2020-06-07T15:53:35Z DEBU             Executing command: [/opt/anypoint/runtimefabric/installer/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/rtf-1.1.1581474166/election/172.31.0.106 true]. fsm/rpc.go:217
2020-06-07T15:53:35Z INFO             Wait for new leader election. phase:/masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal fsm/logger.go:55
2020-06-07T15:53:35Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/elect-ip-172-31-0-106.ap-southeast-2.compute.internal, State=completed) cluster/engine.go:281
```

Upgrade another controller 

```bash
./gravity plan execute --phase=/masters/ip-172-31-1-251.ap-southeast-2.compute.internal
Sun Jun  7 15:56:37 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/drain" locally
Sun Jun  7 15:56:46 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (10 seconds elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (20 seconds elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (30 seconds elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (40 seconds elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (50 seconds elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (1 minute elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (1 minute elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (1 minute elapsed)
  Still executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal (1 minute elapsed)
Sun Jun  7 15:58:20 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/taint" locally
Sun Jun  7 15:58:22 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/uncordon" locally
Sun Jun  7 15:58:23 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/endpoints" locally
Sun Jun  7 15:58:24 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/untaint" locally
Sun Jun  7 15:58:25 UTC Executing "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal/enable-ip-172-31-1-251.ap-southeast-2.compute.internal" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal
Sun Jun  7 15:58:27 UTC Executing phase "/masters/ip-172-31-1-251.ap-southeast-2.compute.internal" finished in 1 minute

```

Check the `/var/log/gravity-system.log` on the node `ip-172-31-1-251`

```bash
$ tail -f /var/log/gravity-system.log
...

2020-06-07T15:56:46Z DEBU             request received args:[plan execute --phase /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-07T15:58:20Z DEBU             completed OK args:[plan execute --phase /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/system-upgrade --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-07T15:58:25Z DEBU             request received args:[plan execute --phase /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/enable-ip-172-31-1-251.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-07T15:58:27Z DEBU             completed OK args:[plan execute --phase /masters/ip-172-31-1-251.ap-southeast-2.compute.internal/enable-ip-172-31-1-251.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
```

If you want to see the details of the phase execution, you need to execute the phase with the `--debug` option on that node. Enable `--debug` on remote node just shows the remote invoking logs. 

```bash
[root@ip-172-31-0-106 installer]# ./gravity plan execute --phase=/masters/ip-172-31-2-11.ap-southeast-2.compute.internal --debug
...

Sun Jun  7 16:04:31 UTC Executing "/masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal" on remote node ip-172-31-2-11.ap-southeast-2.compute.internal
2020-06-07T16:04:31Z DEBU [FSM:REMOT] Dialing... gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] server:node(addr=172.31.2.11, hostname=ip-172-31-2-11.ap-southeast-2.compute.internal, role=controller_node, cluster_role=master) fsm/rpc.go:115
2020-06-07T16:04:31Z DEBU [FSM:REMOT] Executing remotely: [plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] server:ip-172-31-2-11.ap-southeast-2.compute.internal/172.31.2.11 fsm/rpc.go:121
2020-06-07T16:04:31Z DEBU [RPC]       Run ["/var/lib/gravity/site/update/agent/gravity" "plan" "execute" "--phase" "/masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal" "--operation-id" "a3d168e2-52c3-43bd-8499-38718e166f89"]. gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] seq:1 server:ip-172-31-2-11.ap-southeast-2.compute.internal/172.31.2.11 client/agent.go:159
2020-06-07T16:04:32Z INFO [FSM:REMOT] "Sun Jun  7 16:04:32 UTC\tExecuting \"/masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal\" locally\n" CMD:/var/lib/gravity/site/update/agent/gravity#1 gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] server:ip-172-31-2-11.ap-southeast-2.compute.internal/172.31.2.11 client/agent.go:143
2020-06-07T16:04:33Z INFO [FSM:REMOT] "Sun Jun  7 16:04:33 UTC\tExecuting phase \"/masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal\" finished in 1 second \n" CMD:/var/lib/gravity/site/update/agent/gravity#1 gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] server:ip-172-31-2-11.ap-southeast-2.compute.internal/172.31.2.11 client/agent.go:143
2020-06-07T16:04:33Z DEBU [RPC]       Completed. exit:0 gravity:[plan execute --phase /masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] seq:1 server:ip-172-31-2-11.ap-southeast-2.compute.internal/172.31.2.11 client/agent.go:167
2020-06-07T16:04:33Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/ip-172-31-2-11.ap-southeast-2.compute.internal/enable-ip-172-31-2-11.ap-southeast-2.compute.internal, State=completed) cluster/engine.go:281
```

Let's try to execute a phase on `ip-172-31-0-155`. The gravity is not upgraded yet. You need to download the gravity binary from the gravity-store. 

```bash
[root@ip-172-31-0-155 ~]# gravity plan execute --phase=/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal

[ERROR]: Current operation plan should be executed with the gravity binary of version "5.5.38" while this binary is of version "5.5.36".

Please use the gravity binary from the upgrade installer tarball to execute the plan, or download appropriate version from the Ops Center (curl https://get.gravitational.io/telekube/install/5.5.38 | bash).


[root@ip-172-31-0-155 ~]# gravity package export --insecure --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009 gravitational.io/gravity:5.5.38 gravity
[root@ip-172-31-0-155 ~]# chmod +x ./gravity
[root@ip-172-31-0-155 ~]# ./gravity plan execute --phase=/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal
Sun Jun  7 16:23:53 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/drain" on remote node ip-172-31-0-106.ap-southeast-2.compute.internal
Sun Jun  7 16:23:55 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (10 seconds elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (20 seconds elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (30 seconds elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (40 seconds elapsed)
binary package gravitational.io/gravity:5.5.38 installed in /usr/bin/gravity
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (50 seconds elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
  Still executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/system-upgrade" locally (1 minute elapsed)
Sun Jun  7 16:25:44 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/taint" on remote node ip-172-31-0-106.ap-southeast-2.compute.internal
Sun Jun  7 16:25:46 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/uncordon" on remote node ip-172-31-0-106.ap-southeast-2.compute.internal
Sun Jun  7 16:25:49 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/endpoints" on remote node ip-172-31-0-106.ap-southeast-2.compute.internal
Sun Jun  7 16:25:51 UTC Executing "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal/untaint" on remote node ip-172-31-0-106.ap-southeast-2.compute.internal
Sun Jun  7 16:25:53 UTC Executing phase "/nodes/ip-172-31-0-155.ap-southeast-2.compute.internal" finished in 2 minutes

```

Execute the config phase

```bash
gravity plan execute --phase=/config --debug
```

Test the runtime phase

```bash
 gravity plan execute --phase=/runtime/rbac-app
Mon Jun  8 01:35:49 UTC Executing "/runtime/rbac-app" locally
Mon Jun  8 01:35:55 UTC Executing phase "/runtime/rbac-app" finished in 6 seconds
```
Execute the `/runtime/monitoring-app` phase. The pod `monitoring-app-update-dcf3d1-hqq82` is created to complete this step.  

```bash
$ gravity plan execute --phase=/runtime/monitoring-app
Mon Jun  8 01:39:24 UTC Executing "/runtime/monitoring-app" locally
  Still executing "/runtime/monitoring-app" locally (10 seconds elapsed)
  Still executing "/runtime/monitoring-app" locally (20 seconds elapsed)
  Still executing "/runtime/monitoring-app" locally (30 seconds elapsed)
  Still executing "/runtime/monitoring-app" locally (40 seconds elapsed)
  Still executing "/runtime/monitoring-app" locally (50 seconds elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
  Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
Mon Jun  8 01:41:18 UTC Executing phase "/runtime/monitoring-app" finished in 1 minute


$ kubectl get po -n kube-system -owide
NAME                                 READY   STATUS      RESTARTS   AGE    IP             NODE           NOMINATED NODE   READINESS GATES
...
monitoring-app-update-dcf3d1-hqq82   0/1     Completed   0          2m3s   10.244.11.9    172.31.2.11    <none>           <none>
...


$ kubectl logs -n kube-system monitoring-app-update-dcf3d1-hqq82
---> Assuming changeset from the environment: monitoring-5511
---> Checking: monitoring-5511
ERROR: changesets.changeset.gravitational.io "monitoring-5511" not found, details: &StatusDetails{Name:monitoring-5511,Group:changeset.gravitational.io,Kind:changesets,Causes:[],RetryAfterSeconds:0,UID:,}
2020-06-08T01:39:32Z ERRO             "\nERROR REPORT:\nOriginal Error: *trace.NotFoundError changesets.changeset.gravitational.io \"monitoring-5511\" not found, details: &StatusDetails{Name:monitoring-5511,Group:changeset.gravitational.io,Kind:changesets,Causes:[],RetryAfterSeconds:0,UID:,}\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/utils.go:258 github.com/gravitational/rigging.ConvertErrorWithContext\n\t/gopath/src/github.com/gravitational/rigging/utils.go:233 github.com/gravitational/rigging.ConvertError\n\t/gopath/src/github.com/gravitational/rigging/utils.go:233 github.com/gravitational/rigging.ConvertError\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:169 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: changesets.changeset.gravitational.io \"monitoring-5511\" not found, details: &StatusDetails{Name:monitoring-5511,Group:changeset.gravitational.io,Kind:changesets,Causes:[],RetryAfterSeconds:0,UID:,}\n" logrus/exported.go:102
---> Starting update, changeset: monitoring-5511
monitoring-5511 is not found and force is set
---> Creating monitoring namespace
namespace/monitoring configured
---> Deleting resources in kube-system namespace
---> Deleting old 'heapster' resources
Deployment/heapster is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old 'influxdb' resources
Deployment/influxdb is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old 'grafana' resources
Deployment/grafana is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old 'telegraf' resources
Deployment/telegraf is not found, force flag is set, monitoring-5511 not updated, ignoring
DaemonSet/telegraf-node is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old deployment 'kapacitor'
Deployment/kapacitor is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old secrets
Secret/grafana is not found, force flag is set, monitoring-5511 not updated, ignoring
Secret/grafana-influxdb-creds is not found, force flag is set, monitoring-5511 not updated, ignoring
Secret/telegraf-influxdb-creds is not found, force flag is set, monitoring-5511 not updated, ignoring
Secret/heapster-influxdb-creds is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old configmaps
ConfigMap/influxdb is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/grafana-cfg is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/grafana is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/grafana-dashboards-cfg is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/grafana-dashboards is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/grafana-datasources is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/kapacitor-alerts is not found, force flag is set, monitoring-5511 not updated, ignoring
ConfigMap/rollups-default is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting resources in monitoring namespace
---> Deleting old 'heapster' resources
changeset monitoring-5511 updated
---> Deleting old 'influxdb' resources
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
influxdb   1/1     1            1           29h
changeset monitoring-5511 updated
---> Deleting old 'grafana' resources
changeset monitoring-5511 updated
---> Deleting old 'telegraf' resources
changeset monitoring-5511 updated
DaemonSet/telegraf-node is not found, force flag is set, monitoring-5511 not updated, ignoring
---> Deleting old deployment 'kapacitor'
changeset monitoring-5511 updated
---> Deleting old secrets
changeset monitoring-5511 updated
changeset monitoring-5511 updated
changeset monitoring-5511 updated
changeset monitoring-5511 updated
---> Deleting old configmaps
changeset monitoring-5511 updated
changeset monitoring-5511 updated
ConfigMap/grafana is not found, force flag is set, monitoring-5511 not updated, ignoring
changeset monitoring-5511 updated
changeset monitoring-5511 updated
changeset monitoring-5511 updated
changeset monitoring-5511 updated
changeset monitoring-5511 updated
---> Moving smtp-cofiguration secret to monitoring namespace
---> Moving alerting-addresses configmap to monitoring namespace
---> Creating or updating resources
2020-06-08T01:40:08Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:08Z INFO             upsert monitoring/monitoring service_account:monitoring/monitoring rigging/serviceaccount.go:77
2020-06-08T01:40:09Z INFO             upsert monitoring/monitoring-updater service_account:monitoring/monitoring-updater rigging/serviceaccount.go:77
2020-06-08T01:40:09Z INFO             upsert monitoring:metrics cluster_role:monitoring:metrics rigging/roles.go:150
2020-06-08T01:40:10Z INFO             upsert monitoring:metrics cluster_role_binding:monitoring:metrics rigging/roles.go:296
2020-06-08T01:40:10Z INFO             upsert monitoring/monitoring role:monitoring/monitoring rigging/roles.go:77
2020-06-08T01:40:11Z INFO             upsert monitoring/monitoring role_binding:monitoring/monitoring rigging/roles.go:223
2020-06-08T01:40:12Z INFO             upsert monitoring/monitoring:updater role:monitoring/monitoring:updater rigging/roles.go:77
2020-06-08T01:40:13Z INFO             upsert monitoring/monitoring-updater role_binding:monitoring/monitoring-updater rigging/roles.go:223
changeset monitoring-5511 updated
2020-06-08T01:40:13Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:13Z INFO             upsert secret monitoring/telegraf-influxdb-creds cs:namespace=default, name=monitoring-5511, operations=24) secret:monitoring/telegraf-influxdb-creds rigging/changeset.go:1725
2020-06-08T01:40:13Z DEBU             existing secret not found cs:namespace=default, name=monitoring-5511, operations=24) secret:monitoring/telegraf-influxdb-creds rigging/changeset.go:1728
2020-06-08T01:40:13Z INFO             upsert monitoring/telegraf-influxdb-creds secret:monitoring/telegraf-influxdb-creds rigging/secret.go:77
2020-06-08T01:40:13Z INFO             upsert secret monitoring/grafana-influxdb-creds cs:namespace=default, name=monitoring-5511, operations=25) secret:monitoring/grafana-influxdb-creds rigging/changeset.go:1725
2020-06-08T01:40:13Z DEBU             existing secret not found cs:namespace=default, name=monitoring-5511, operations=25) secret:monitoring/grafana-influxdb-creds rigging/changeset.go:1728
2020-06-08T01:40:13Z INFO             upsert monitoring/grafana-influxdb-creds secret:monitoring/grafana-influxdb-creds rigging/secret.go:77
2020-06-08T01:40:14Z INFO             upsert secret monitoring/heapster-influxdb-creds cs:namespace=default, name=monitoring-5511, operations=26) secret:monitoring/heapster-influxdb-creds rigging/changeset.go:1725
2020-06-08T01:40:14Z DEBU             existing secret not found cs:namespace=default, name=monitoring-5511, operations=26) secret:monitoring/heapster-influxdb-creds rigging/changeset.go:1728
2020-06-08T01:40:14Z INFO             upsert monitoring/heapster-influxdb-creds secret:monitoring/heapster-influxdb-creds rigging/secret.go:77
2020-06-08T01:40:14Z INFO             upsert secret monitoring/grafana cs:namespace=default, name=monitoring-5511, operations=27) secret:monitoring/grafana rigging/changeset.go:1725
2020-06-08T01:40:14Z DEBU             existing secret not found cs:namespace=default, name=monitoring-5511, operations=27) secret:monitoring/grafana rigging/changeset.go:1728
2020-06-08T01:40:14Z INFO             upsert monitoring/grafana secret:monitoring/grafana rigging/secret.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:14Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:15Z INFO             upsert secret monitoring/smtp-configuration cs:namespace=default, name=monitoring-5511, operations=28) secret:monitoring/smtp-configuration rigging/changeset.go:1725
2020-06-08T01:40:15Z INFO             upsert monitoring/smtp-configuration secret:monitoring/smtp-configuration rigging/secret.go:77
2020-06-08T01:40:15Z INFO             upsert configmap monitoring/alerting-addresses configMap:monitoring/alerting-addresses cs:namespace=default, name=monitoring-5511, operations=29) rigging/changeset.go:1693
2020-06-08T01:40:15Z INFO             upsert monitoring/alerting-addresses configMap:monitoring/alerting-addresses rigging/configmap.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:15Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:15Z INFO             upsert deployment monitoring/influxdb cs:namespace=default, name=monitoring-5511, operations=30) deployment:monitoring/influxdb rigging/changeset.go:1443
2020-06-08T01:40:15Z DEBU             existing deployment not found cs:namespace=default, name=monitoring-5511, operations=30) deployment:monitoring/influxdb rigging/changeset.go:1446
2020-06-08T01:40:15Z INFO             upsert monitoring/influxdb deployment:monitoring/influxdb rigging/deployment.go:121
2020-06-08T01:40:15Z INFO             upsert service monitoring/influxdb cs:namespace=default, name=monitoring-5511, operations=31) service:monitoring/influxdb rigging/changeset.go:1475
2020-06-08T01:40:15Z INFO             upsert monitoring/influxdb service:monitoring/influxdb rigging/service.go:77
2020-06-08T01:40:15Z INFO             upsert configmap monitoring/influxdb configMap:monitoring/influxdb cs:namespace=default, name=monitoring-5511, operations=32) rigging/changeset.go:1693
2020-06-08T01:40:15Z DEBU             existing configmap not found configMap:monitoring/influxdb cs:namespace=default, name=monitoring-5511, operations=32) rigging/changeset.go:1696
2020-06-08T01:40:16Z INFO             upsert monitoring/influxdb configMap:monitoring/influxdb rigging/configmap.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:16Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:16Z INFO             upsert configmap monitoring/grafana-cfg configMap:monitoring/grafana-cfg cs:namespace=default, name=monitoring-5511, operations=33) rigging/changeset.go:1693
2020-06-08T01:40:16Z DEBU             existing configmap not found configMap:monitoring/grafana-cfg cs:namespace=default, name=monitoring-5511, operations=33) rigging/changeset.go:1696
2020-06-08T01:40:16Z INFO             upsert monitoring/grafana-cfg configMap:monitoring/grafana-cfg rigging/configmap.go:77
2020-06-08T01:40:16Z INFO             upsert deployment monitoring/grafana cs:namespace=default, name=monitoring-5511, operations=34) deployment:monitoring/grafana rigging/changeset.go:1443
2020-06-08T01:40:16Z DEBU             existing deployment not found cs:namespace=default, name=monitoring-5511, operations=34) deployment:monitoring/grafana rigging/changeset.go:1446
2020-06-08T01:40:16Z INFO             upsert monitoring/grafana deployment:monitoring/grafana rigging/deployment.go:121
2020-06-08T01:40:16Z INFO             upsert service monitoring/grafana cs:namespace=default, name=monitoring-5511, operations=35) service:monitoring/grafana rigging/changeset.go:1475
2020-06-08T01:40:16Z INFO             upsert monitoring/grafana service:monitoring/grafana rigging/service.go:77
2020-06-08T01:40:17Z INFO             upsert configmap monitoring/grafana-datasources configMap:monitoring/grafana-datasources cs:namespace=default, name=monitoring-5511, operations=36) rigging/changeset.go:1693
2020-06-08T01:40:17Z DEBU             existing configmap not found configMap:monitoring/grafana-datasources cs:namespace=default, name=monitoring-5511, operations=36) rigging/changeset.go:1696
2020-06-08T01:40:17Z INFO             upsert monitoring/grafana-datasources configMap:monitoring/grafana-datasources rigging/configmap.go:77
2020-06-08T01:40:18Z INFO             upsert configmap monitoring/grafana-dashboards-cfg configMap:monitoring/grafana-dashboards-cfg cs:namespace=default, name=monitoring-5511, operations=37) rigging/changeset.go:1693
2020-06-08T01:40:18Z DEBU             existing configmap not found configMap:monitoring/grafana-dashboards-cfg cs:namespace=default, name=monitoring-5511, operations=37) rigging/changeset.go:1696
2020-06-08T01:40:18Z INFO             upsert monitoring/grafana-dashboards-cfg configMap:monitoring/grafana-dashboards-cfg rigging/configmap.go:77
2020-06-08T01:40:18Z INFO             upsert configmap monitoring/grafana-dashboards configMap:monitoring/grafana-dashboards cs:namespace=default, name=monitoring-5511, operations=38) rigging/changeset.go:1693
2020-06-08T01:40:18Z DEBU             existing configmap not found configMap:monitoring/grafana-dashboards cs:namespace=default, name=monitoring-5511, operations=38) rigging/changeset.go:1696
2020-06-08T01:40:19Z INFO             upsert monitoring/grafana-dashboards configMap:monitoring/grafana-dashboards rigging/configmap.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:19Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:19Z INFO             upsert deployment monitoring/heapster cs:namespace=default, name=monitoring-5511, operations=39) deployment:monitoring/heapster rigging/changeset.go:1443
2020-06-08T01:40:19Z DEBU             existing deployment not found cs:namespace=default, name=monitoring-5511, operations=39) deployment:monitoring/heapster rigging/changeset.go:1446
2020-06-08T01:40:19Z INFO             upsert monitoring/heapster deployment:monitoring/heapster rigging/deployment.go:121
2020-06-08T01:40:19Z INFO             upsert service monitoring/heapster cs:namespace=default, name=monitoring-5511, operations=40) service:monitoring/heapster rigging/changeset.go:1475
2020-06-08T01:40:19Z INFO             upsert monitoring/heapster service:monitoring/heapster rigging/service.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:20Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:20Z INFO             upsert deployment monitoring/kapacitor cs:namespace=default, name=monitoring-5511, operations=41) deployment:monitoring/kapacitor rigging/changeset.go:1443
2020-06-08T01:40:20Z DEBU             existing deployment not found cs:namespace=default, name=monitoring-5511, operations=41) deployment:monitoring/kapacitor rigging/changeset.go:1446
2020-06-08T01:40:20Z INFO             upsert monitoring/kapacitor deployment:monitoring/kapacitor rigging/deployment.go:121
2020-06-08T01:40:20Z INFO             upsert service monitoring/kapacitor cs:namespace=default, name=monitoring-5511, operations=42) service:monitoring/kapacitor rigging/changeset.go:1475
2020-06-08T01:40:20Z INFO             upsert monitoring/kapacitor service:monitoring/kapacitor rigging/service.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:21Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:21Z INFO             upsert deployment monitoring/telegraf cs:namespace=default, name=monitoring-5511, operations=43) deployment:monitoring/telegraf rigging/changeset.go:1443
2020-06-08T01:40:21Z DEBU             existing deployment not found cs:namespace=default, name=monitoring-5511, operations=43) deployment:monitoring/telegraf rigging/changeset.go:1446
2020-06-08T01:40:21Z INFO             upsert monitoring/telegraf deployment:monitoring/telegraf rigging/deployment.go:121
2020-06-08T01:40:22Z INFO             upsert daemon set monitoring/telegraf-node-master cs:namespace=default, name=monitoring-5511, operations=44) ds:monitoring/telegraf-node-master rigging/changeset.go:1347
2020-06-08T01:40:22Z INFO             upsert monitoring/telegraf-node-master daemonset:monitoring/telegraf-node-master rigging/ds.go:122
2020-06-08T01:40:22Z INFO             delete monitoring/telegraf-node-master daemonset:monitoring/telegraf-node-master rigging/ds.go:85
2020-06-08T01:40:22Z INFO             found pod monitoring/telegraf-node-master-kqmmr on node 172.31.0.106 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:40:22Z INFO             found pod monitoring/telegraf-node-master-rpz4q on node 172.31.2.11 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:40:22Z INFO             found pod monitoring/telegraf-node-master-wrvz5 on node 172.31.1.251 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:40:22Z INFO             deleting current daemon set daemonset:monitoring/telegraf-node-master rigging/ds.go:96
2020-06-08T01:40:34Z DEBU             deleting pod telegraf-node-master-kqmmr daemonset:monitoring/telegraf-node-master rigging/utils.go:317
2020-06-08T01:40:34Z DEBU             deleting pod telegraf-node-master-rpz4q daemonset:monitoring/telegraf-node-master rigging/utils.go:317
2020-06-08T01:40:34Z DEBU             deleting pod telegraf-node-master-wrvz5 daemonset:monitoring/telegraf-node-master rigging/utils.go:317
2020-06-08T01:40:34Z INFO             creating new daemon set daemonset:monitoring/telegraf-node-master rigging/ds.go:145
2020-06-08T01:40:35Z INFO             upsert daemon set monitoring/telegraf-node-worker cs:namespace=default, name=monitoring-5511, operations=45) ds:monitoring/telegraf-node-worker rigging/changeset.go:1347
2020-06-08T01:40:35Z INFO             upsert monitoring/telegraf-node-worker daemonset:monitoring/telegraf-node-worker rigging/ds.go:122
2020-06-08T01:40:35Z INFO             delete monitoring/telegraf-node-worker daemonset:monitoring/telegraf-node-worker rigging/ds.go:85
2020-06-08T01:40:35Z INFO             found pod monitoring/telegraf-node-worker-lcznf on node 172.31.1.37 daemonset:monitoring/telegraf-node-worker rigging/utils.go:117
2020-06-08T01:40:35Z INFO             found pod monitoring/telegraf-node-worker-rl5fg on node 172.31.0.155 daemonset:monitoring/telegraf-node-worker rigging/utils.go:117
2020-06-08T01:40:35Z INFO             deleting current daemon set daemonset:monitoring/telegraf-node-worker rigging/ds.go:96
2020-06-08T01:40:48Z DEBU             deleting pod telegraf-node-worker-lcznf daemonset:monitoring/telegraf-node-worker rigging/utils.go:317
2020-06-08T01:40:48Z DEBU             deleting pod telegraf-node-worker-rl5fg daemonset:monitoring/telegraf-node-worker rigging/utils.go:317
2020-06-08T01:40:48Z INFO             creating new daemon set daemonset:monitoring/telegraf-node-worker rigging/ds.go:145
changeset monitoring-5511 updated
2020-06-08T01:40:48Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:48Z INFO             upsert configmap monitoring/rollups-default configMap:monitoring/rollups-default cs:namespace=default, name=monitoring-5511, operations=46) rigging/changeset.go:1693
2020-06-08T01:40:48Z DEBU             existing configmap not found configMap:monitoring/rollups-default cs:namespace=default, name=monitoring-5511, operations=46) rigging/changeset.go:1696
2020-06-08T01:40:48Z INFO             upsert monitoring/rollups-default configMap:monitoring/rollups-default rigging/configmap.go:77
changeset monitoring-5511 updated
2020-06-08T01:40:48Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:49Z INFO             upsert configmap monitoring/kapacitor-alerts configMap:monitoring/kapacitor-alerts cs:namespace=default, name=monitoring-5511, operations=47) rigging/changeset.go:1693
2020-06-08T01:40:49Z DEBU             existing configmap not found configMap:monitoring/kapacitor-alerts cs:namespace=default, name=monitoring-5511, operations=47) rigging/changeset.go:1696
2020-06-08T01:40:49Z INFO             upsert monitoring/kapacitor-alerts configMap:monitoring/kapacitor-alerts rigging/configmap.go:77
changeset monitoring-5511 updated
deployment.extensions/influxdb patched
---> Checking status
2020-06-08T01:40:49Z DEBU             changeset init logrus/exported.go:77
2020-06-08T01:40:51Z INFO             "attempt 2, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, updated: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:158 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:128 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, updated: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:40:55Z INFO             "attempt 3, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:162 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:40:59Z INFO             "attempt 4, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:162 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:41:02Z INFO             "attempt 5, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:162 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:41:06Z INFO             "attempt 6, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:162 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:41:10Z INFO             "attempt 7, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:162 github.com/gravitational/rigging.(*DeploymentControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:463 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:337 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message: deployment monitoring/influxdb not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127
2020-06-08T01:41:16Z INFO             found pod monitoring/telegraf-node-master-g9br7 on node 172.31.0.106 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:41:16Z INFO             found pod monitoring/telegraf-node-master-p9s4x on node 172.31.2.11 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:41:16Z INFO             found pod monitoring/telegraf-node-master-pmhvg on node 172.31.1.251 daemonset:monitoring/telegraf-node-master rigging/utils.go:117
2020-06-08T01:41:16Z INFO             node 172.31.0.106: pod monitoring/telegraf-node-master-g9br7 is up and running daemonset:monitoring/telegraf-node-master rigging/utils.go:199
2020-06-08T01:41:16Z INFO             found pod monitoring/telegraf-node-worker-fhw6n on node 172.31.1.37 daemonset:monitoring/telegraf-node-worker rigging/utils.go:117
2020-06-08T01:41:16Z INFO             found pod monitoring/telegraf-node-worker-jcmm9 on node 172.31.0.155 daemonset:monitoring/telegraf-node-worker rigging/utils.go:117
2020-06-08T01:41:16Z INFO             node 172.31.0.155: pod monitoring/telegraf-node-worker-jcmm9 is up and running daemonset:monitoring/telegraf-node-worker rigging/utils.go:199
no errors detected for monitoring-5511
---> Freezing
changeset monitoring-5511 frozen, no further modifications are allowed

```

Upgrade gravity-site. The upgrade is done by `site-app-update-090660-gvbz5` on the k8s Runtime level

```bash
$ gravity plan execute --phase=/runtime/site
Mon Jun  8 01:45:30 UTC Executing "/runtime/site" locally
  Still executing "/runtime/site" locally (10 seconds elapsed)
  Still executing "/runtime/site" locally (20 seconds elapsed)
  Still executing "/runtime/site" locally (30 seconds elapsed)
  Still executing "/runtime/site" locally (40 seconds elapsed)
Mon Jun  8 01:46:14 UTC Executing phase "/runtime/site" finished in 44 seconds
$ kubectl get po -n kube-system -owide

$ kubectl logs -n kube-system site-app-update-090660-gvbz5 -f
+ echo Assuming changeset from the environment: site-5538
Assuming changeset from the environment: site-5538
Checking: site-5538
+ [ update = update ]
+ echo Checking: site-5538
+ rig status site-5538 --retry-attempts=1 --retry-period=1s --quiet
+ echo Starting update, changeset: site-5538
+ rig cs delete --force -c cs/site-5538
Starting update, changeset: site-5538
site-5538 is not found and force is set
+ echo Deleting old configmaps/gravity-site
+ rig delete configmaps/gravity-site --resource-namespace=kube-system --force
Deleting old configmaps/gravity-site
changeset site-5538 updated
+ echo Creating or updating configmap
+ rig configmap gravity-site --resource-namespace=kube-system --from-file=/var/lib/gravity/resources/config
Creating or updating configmap
changeset site-5538 updated
+ [ -n true ]
+ rig upsert -f /var/lib/gravity/resources/site.yaml --debug
2020-06-08T01:45:38Z DEBU             changeset init rigging/changeset.go:1755
2020-06-08T01:45:38Z INFO             upsert kube-system/gravity-site service_account:kube-system/gravity-site rigging/serviceaccount.go:77
2020-06-08T01:45:38Z INFO             upsert kube-system/gravity-site role:kube-system/gravity-site rigging/roles.go:77
2020-06-08T01:45:38Z INFO             upsert kube-system/gravity-site role_binding:kube-system/gravity-site rigging/roles.go:223
2020-06-08T01:45:39Z INFO             upsert gravity-site cluster_role:gravity-site rigging/roles.go:150
2020-06-08T01:45:40Z INFO             upsert gravity-site cluster_role_binding:gravity-site rigging/roles.go:296
2020-06-08T01:45:40Z INFO             upsert daemon set kube-system/gravity-site cs:namespace=default, name=site-5538, operations=7) ds:kube-system/gravity-site rigging/changeset.go:1347
2020-06-08T01:45:41Z INFO             upsert kube-system/gravity-site daemonset:kube-system/gravity-site rigging/ds.go:122
2020-06-08T01:45:41Z INFO             delete kube-system/gravity-site daemonset:kube-system/gravity-site rigging/ds.go:85
2020-06-08T01:45:41Z INFO             found pod kube-system/gravity-site-b27ks on node 172.31.2.11 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:41Z INFO             found pod kube-system/gravity-site-b5wnp on node 172.31.1.251 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:41Z INFO             found pod kube-system/gravity-site-bz784 on node 172.31.0.106 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:41Z INFO             deleting current daemon set daemonset:kube-system/gravity-site rigging/ds.go:96
2020-06-08T01:45:52Z DEBU             deleting pod gravity-site-b27ks daemonset:kube-system/gravity-site rigging/utils.go:316
2020-06-08T01:45:52Z DEBU             deleting pod gravity-site-b5wnp daemonset:kube-system/gravity-site rigging/utils.go:316
2020-06-08T01:45:52Z DEBU             deleting pod gravity-site-bz784 daemonset:kube-system/gravity-site rigging/utils.go:316
2020-06-08T01:45:52Z INFO             creating new daemon set daemonset:kube-system/gravity-site rigging/ds.go:144
2020-06-08T01:45:52Z INFO             upsert service kube-system/gravity-site cs:namespace=default, name=site-5538, operations=8) service:kube-system/gravity-site rigging/changeset.go:1475
2020-06-08T01:45:52Z INFO             upsert kube-system/gravity-site service:kube-system/gravity-site rigging/service.go:77
changeset site-5538 updated
+ kubectl get namespaces/monitoring
+ rig upsert -f /var/lib/gravity/resources/monitoring.yaml --debug
2020-06-08T01:45:52Z DEBU             changeset init rigging/changeset.go:1755
2020-06-08T01:45:52Z INFO             upsert monitoring/gravity-site role:monitoring/gravity-site rigging/roles.go:77
2020-06-08T01:45:52Z INFO             upsert monitoring/gravity-site role_binding:monitoring/gravity-site rigging/roles.go:223
changeset site-5538 updated
+ kubectl get configmap/gravity-opscenter --namespace=kube-system
+ echo Checking status
+ rig status site-5538 --retry-attempts=120 --retry-period=1s --debug
Checking status
2020-06-08T01:45:53Z DEBU             changeset init rigging/changeset.go:1755
2020-06-08T01:45:53Z INFO             found pod kube-system/gravity-site-4f5nm on node 172.31.1.251 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:53Z INFO             found pod kube-system/gravity-site-87mnd on node 172.31.2.11 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:53Z INFO             found pod kube-system/gravity-site-8n8hc on node 172.31.0.106 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:53Z INFO             "attempt 2, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError pod kube-system/gravity-site-8n8hc is not running yet, status: \"Pending\", ready: false\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/utils.go:201 github.com/gravitational/rigging.checkRunningAndReady\n\t/gopath/src/github.com/gravitational/rigging/utils.go:175 github.com/gravitational/rigging.checkRunning\n\t/gopath/src/github.com/gravitational/rigging/ds.go:189 github.com/gravitational/rigging.(*DSControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:378 github.com/gravitational/rigging.(*Changeset).statusDaemonSet\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:329 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:128 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:207 runtime.main\n\t/go/src/runtime/asm_amd64.s:2362 runtime.goexit\nUser Message: pod kube-system/gravity-site-8n8hc is not running yet, status: \"Pending\", ready: false\n, retry in 1s" rigging/utils.go:129
2020-06-08T01:45:54Z INFO             found pod kube-system/gravity-site-4f5nm on node 172.31.1.251 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:54Z INFO             found pod kube-system/gravity-site-87mnd on node 172.31.2.11 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:54Z INFO             found pod kube-system/gravity-site-8n8hc on node 172.31.0.106 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:54Z INFO             "attempt 3, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError pod kube-system/gravity-site-8n8hc is not running yet, status: \"Pending\", ready: false\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/utils.go:201 github.com/gravitational/rigging.checkRunningAndReady\n\t/gopath/src/github.com/gravitational/rigging/utils.go:175 github.com/gravitational/rigging.checkRunning\n\t/gopath/src/github.com/gravitational/rigging/ds.go:189 github.com/gravitational/rigging.(*DSControl).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:378 github.com/gravitational/rigging.(*Changeset).statusDaemonSet\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:329 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:196 github.com/gravitational/rigging.(*Changeset).Status.func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:189 github.com/gravitational/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.run\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:207 runtime.main\n\t/go/src/runtime/asm_amd64.s:2362 runtime.goexit\nUser Message: pod kube-system/gravity-site-8n8hc is not running yet, status: \"Pending\", ready: false\n, retry in 1s" rigging/utils.go:129
2020-06-08T01:45:55Z INFO             found pod kube-system/gravity-site-4f5nm on node 172.31.1.251 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:55Z INFO             found pod kube-system/gravity-site-87mnd on node 172.31.2.11 daemonset:kube-system/gravity-site rigging/utils.go:117
2020-06-08T01:45:55Z INFO             found pod kube-system/gravity-site-8n8hc on node 172.31.0.106 daemonset:kube-system/gravity-site rigging/utils.go:117
no errors detected for site-5538
+ echo Freezing
+ rig freeze
Freezing
changeset site-5538 frozen, no further modifications are allowed
```

Run the `/runtime/kubernetes`

```bash
$ gravity plan execute --phase=/runtime/kubernetes
Mon Jun  8 01:48:47 UTC Executing "/runtime/kubernetes" locally
Mon Jun  8 01:48:49 UTC Executing phase "/runtime/kubernetes" finished in 2 seconds

```

The `/migration`

```bash

$ gravity plan execute --phase=/migration
Mon Jun  8 01:50:43 UTC Executing "/migration/labels" locally
Mon Jun  8 01:50:44 UTC Executing phase "/migration" finished in 1 second
```

The application phase `/app`

```bash
$ gravity plan execute --phase=/app
Mon Jun  8 01:51:36 UTC Executing "/app/runtime-fabric" locally
  Still executing "/app/runtime-fabric" locally (10 seconds elapsed)
Mon Jun  8 01:51:56 UTC Executing phase "/app" finished in 20 seconds

$  kubectl logs -n kube-system rtf-install-hook-e55851-gfsns -f
deployment.extensions/tiller-deploy patched (no change)
deployment.extensions/influxdb patched
deployment.extensions/kapacitor patched
deployment.extensions/grafana patched
Error from server (NotFound): namespaces "nmonitoring" not found
deployment.extensions/log-collector patched (no change)
Error from server (NotFound): namespaces "nmonitoring" not found
Error from server (NotFound): configmaps "monitor-resource-version" not found
No resources found
configmap/monitor-resource-version created
pod "resource-cache-79f4c85b55-vfl2d" deleted
CLUSTER_VERSION: 1.1.1583954392-3121bcd
configmap "cluster-info" deleted
configmap/cluster-info replaced
configmap/backup-script-default unchanged
InfluxDB credentials already in place.

```

Garbage cleanup

```bash
$ gravity plan execute --phase=/gc
Mon Jun  8 01:53:58 UTC Executing "/gc/ip-172-31-0-106.ap-southeast-2.compute.internal" locally
Mon Jun  8 01:54:00 UTC Executing "/gc/ip-172-31-1-251.ap-southeast-2.compute.internal" on remote node ip-172-31-1-251.ap-southeast-2.compute.internal
Mon Jun  8 01:54:02 UTC Executing "/gc/ip-172-31-0-155.ap-southeast-2.compute.internal" on remote node ip-172-31-0-155.ap-southeast-2.compute.internal
Mon Jun  8 01:54:06 UTC Executing "/gc/ip-172-31-2-11.ap-southeast-2.compute.internal" on remote node ip-172-31-2-11.ap-southeast-2.compute.internal
Mon Jun  8 01:54:08 UTC Executing "/gc/ip-172-31-1-37.ap-southeast-2.compute.internal" on remote node ip-172-31-1-37.ap-southeast-2.compute.internal
Mon Jun  8 01:54:12 UTC Executing phase "/gc" finished in 14 seconds

# on the node ip-172-31-0-155
$ tail -f /var/log/gravity-system.log
...
2020-06-08T01:54:02Z DEBU             request received args:[plan execute --phase /gc/ip-172-31-0-155.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
2020-06-08T01:54:05Z DEBU             completed OK args:[plan execute --phase /gc/ip-172-31-0-155.ap-southeast-2.compute.internal --operation-id a3d168e2-52c3-43bd-8499-38718e166f89] request:Command utils/logging.go:94
...
```
Complete the upgrade

```bash

$ gravity plan complete

$ gravity status
Cluster name:   rtf-1.1.1581474166
Cluster status:   active
Application:    runtime-fabric, version 1.1.1583954392-3121bcd
Gravity version:  5.5.38 (client) / 5.5.38 (server)
Join token:   bW3fK7BsYusypWG6
Periodic updates: Not Configured
Remote support:   Not Configured
Last completed operation:
    * operation_update (a3d168e2-52c3-43bd-8499-38718e166f89)
      started:    Sun Jun  7 14:58 UTC (11 hours ago)
      completed:  Mon Jun  8 01:57 UTC (1 minute ago)
Cluster endpoints:
    * Authentication gateway:
        - 172.31.0.106:32009
        - 172.31.1.251:32009
        - 172.31.2.11:32009
    * Cluster management URL:
        - https://172.31.0.106:32009
        - https://172.31.1.251:32009
        - https://172.31.2.11:32009
Cluster nodes:
    Masters:
        * ip-172-31-0-106.ap-southeast-2.compute.internal (172.31.0.106, controller_node)
            Status: healthy
        * ip-172-31-1-251.ap-southeast-2.compute.internal (172.31.1.251, controller_node)
            Status: healthy
        * ip-172-31-2-11.ap-southeast-2.compute.internal (172.31.2.11, controller_node)
            Status: healthy
    Nodes:
        * ip-172-31-0-155.ap-southeast-2.compute.internal (172.31.0.155, worker_node)
            Status: healthy
        * ip-172-31-1-37.ap-southeast-2.compute.internal (172.31.1.37, worker_node)
            Status: healthy
```

