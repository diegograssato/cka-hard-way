#Implantando o servidor NFS em uma máquina virtual


```bash
#!/bin/bash

# This script should be executed on Linux Ubuntu Virtual Machine

EXPORT_DIRECTORY=${1:-/export/data}
DATA_DIRECTORY=${2:-/data}
AKS_SUBNET=${3:-*}

echo "Updating packages"
apt-get -y update

echo "Installing NFS kernel server"

apt-get -y install nfs-kernel-server

echo "Making data directory ${DATA_DIRECTORY}"
mkdir -p ${DATA_DIRECTORY}

echo "Making new directory to be exported and linked to data directory: ${EXPORT_DIRECTORY}"
mkdir -p ${EXPORT_DIRECTORY}

echo "Mount binding ${DATA_DIRECTORY} to ${EXPORT_DIRECTORY}"
mount --bind ${DATA_DIRECTORY} ${EXPORT_DIRECTORY}

echo "Giving 777 permissions to ${EXPORT_DIRECTORY} directory"
chmod 777 "${EXPORT_DIRECTORY}"

PARENT_DIR="$(dirname "$EXPORT_DIRECTORY")"
echo "Giving 777 permissions to parent: ${PARENT_DIR} directory"
chmod 777 -R "${PARENT_DIR}"

echo "Appending bound directories into fstab"
echo "${DATA_DIRECTORY}    ${EXPORT_DIRECTORY}   none    bind  0  0" >> /etc/fstab

echo "Appending localhost and Kubernetes subnet address ${AKS_SUBNET} to exports configuration file"
echo "/export        ${AKS_SUBNET}(rw,async,insecure,fsid=0,crossmnt,no_subtree_check)" >> /etc/exports
echo "/export        localhost(rw,async,insecure,fsid=0,crossmnt,no_subtree_check)" >> /etc/exports

nohup service nfs-kernel-server restart

```




---

piVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer

---

apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-share-volume
  labels:
    type: nfs
spec:
  storageClassName: standard
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.1.2.51
    path: /export/data

 

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-share-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 1Gi
  selector: 
    matchLabels:
      type: nfs

---
kind: Pod
apiVersion: v1
metadata:
  name: pod-using-nfs
spec:
  containers:
    - name: app
      image: alpine
      volumeMounts:
      - name: data
        mountPath: /var/nfs # Please change the destination you like the share to be mounted too
      command: ["/bin/sh"]
      args: ["-c", "while true; do date >> /var/nfs/file.txt; sleep 5; done"]
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nfs-share-claim

```

kubectl create -f volume.yaml

kubectl get pod

kubectl exec -it pod-using-nfs sh
 mount |grep nfs

# Fazer o Nat

```
echo "1" >/proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.1.2.0/24 -j MASQUERADE
```
