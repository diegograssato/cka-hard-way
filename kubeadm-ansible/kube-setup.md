### Runnig with ansible

```bash

ansible-playbook -i kube-cluster/hosts kube-cluster/initial.yml
ansible-playbook -i kube-cluster/hosts kube-cluster/kube-dependencies.yml

ansible-playbook -i kube-cluster/hosts kube-cluster/master.yml
kubectl get nodes

ansible-playbook -i kube-cluster/hosts kube-cluster/workers.yml
kubectl get nodes
 

Testing

kubectl run nginx --image=nginx --port 80
kubectl expose deploy nginx --port 80 --target-port 80 --type NodePort
kubectl get services

kubectl delete service nginx
kubectl get services
kubectl delete deployment nginx
kubectl get deployments

```

## CoreOS

```bash
https://coreos.com/os/docs/latest/booting-with-libvirt.html

```

## Ubuntu

```bash

https://marc.xn--wckerlin-0za.ch/computer/kubernetes-on-ubuntu-16-04

```


## Centos

```bash

http://www.paulinomreyes.com/?p=225

```




### Fix

```
vi /etc/selinux/config
SELINUX=disabled
SELINUXTYPE=targeted
SETLOCALDEFS=0

/etc/systemd/network/99-default.link
[Link]
MACAddressPolicy=none

systemctl restart systemd-udevd
 
```