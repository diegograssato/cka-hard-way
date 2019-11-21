#!/usr/bin/env bash

# Update Repositories
sudo apt-get update

# Determine Ubuntu Version
. /etc/lsb-release

# Decide on package to install for `add-apt-repository` command
#
# USE_COMMON=1 when using a distribution over 12.04
# USE_COMMON=0 when using a distribution at 12.04 or older
USE_COMMON=$(echo "$DISTRIB_RELEASE > 12.04" | bc)

if [ "$USE_COMMON" -eq "1" ];
then
    sudo apt-get install -y software-properties-common
else
    sudo apt-get install -y python-software-properties
fi

# Add Ansible Repository & Install Ansible
sudo add-apt-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible 


ansible-playbook -i inventories/hosts playbook.yml


# Update host

ansible-playbook -i inventories/hosts playbook.yml --tags etc_hosts


# User guide
ansible-playbook -i inventories/hosts kube-virt.yml --tags vm_info

https://kubevirt.io/user-guide/#/workloads/virtual-machines/expose-service
https://www.digitalocean.com/community/tutorials/how-to-use-ansible-to-install-and-set-up-docker-on-ubuntu-18-04




- Set's IP addresses in the range 192.168.5

    | VM            |  VM Name               | Purpose       | IP           | Forwarded Port   |
    | ------------  | ---------------------- |:-------------:| ------------:| ----------------:|
    | master-1      | kubernetes-ha-master-1 | Master        | 10.1.2.10    |     2711         |
    | master-2      | kubernetes-ha-master-2 | Master        | 10.1.2.11    |     2712         |
    | worker-1      | kubernetes-ha-worker-1 | Worker        | 10.1.2.20    |     2721         |
    | worker-2      | kubernetes-ha-worker-2 | Worker        | 10.1.2.21    |     2722         |
    | loadbalancer  | kubernetes-ha-lb       | LoadBalancer  | 10.1.2.100   |     2730         |


- Set's IP addresses in the range 192.168.5

    | VM            |  VM Name               | Purpose       | IP           | Forwarded Port   |
    | ------------  | ---------------------- |:-------------:| ------------:| ----------------:|
    | master-1      | kubernetes-ha-master-1 | Master        | 192.168.5.11 |     2711         |
    | master-2      | kubernetes-ha-master-2 | Master        | 192.168.5.12 |     2712         |
    | worker-1      | kubernetes-ha-worker-1 | Worker        | 192.168.5.21 |     2721         |
    | worker-2      | kubernetes-ha-worker-2 | Worker        | 192.168.5.22 |     2722         |
    | loadbalancer  | kubernetes-ha-lb       | LoadBalancer  | 192.168.5.30 |     2730         |



generate-certificates.sh
# Create private key for CA
openssl genrsa -out ca.key 2048

# Create CSR using the private key
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr

# Self sign the csr using its own private key
openssl x509 -req -in ca.csr -signkey ca.key -CAcreateserial  -out ca.crt -days 1000


# Generate private key for admin user
openssl genrsa -out admin.key 2048

# Generate CSR for admin user. Note the OU.
openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr

# Sign certificate for admin user using CA servers private key
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out admin.crt -days 1000

openssl genrsa -out kube-controller-manager.key 2048
openssl req -new -key kube-controller-manager.key -subj "/CN=system:kube-controller-manager" -out kube-controller-manager.csr
openssl x509 -req -in kube-controller-manager.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-controller-manager.crt -days 1000

openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key -subj "/CN=system:kube-proxy" -out kube-proxy.csr
openssl x509 -req -in kube-proxy.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-proxy.crt -days 1000

openssl genrsa -out kube-scheduler.key 2048
openssl req -new -key kube-scheduler.key -subj "/CN=system:kube-scheduler" -out kube-scheduler.csr
openssl x509 -req -in kube-scheduler.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-scheduler.crt -days 1000


cat > openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = 10.1.2.10
IP.3 = 10.1.2.11
IP.4 = 10.1.2.100
IP.5 = 127.0.0.1
EOF

openssl genrsa -out kube-apiserver.key 2048
openssl req -new -key kube-apiserver.key -subj "/CN=kube-apiserver" -out kube-apiserver.csr -config openssl.cnf
openssl x509 -req -in kube-apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-apiserver.crt -extensions v3_req -extfile openssl.cnf -days 1000

cat > openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 10.1.2.10
IP.2 = 10.1.2.11
IP.3 = 127.0.0.1
EOF

openssl genrsa -out etcd-server.key 2048
openssl req -new -key etcd-server.key -subj "/CN=etcd-server" -out etcd-server.csr -config openssl-etcd.cnf
openssl x509 -req -in etcd-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out etcd-server.crt -extensions v3_req -extfile openssl-etcd.cnf -days 1000

openssl genrsa -out service-account.key 2048
openssl req -new -key service-account.key -subj "/CN=service-accounts" -out service-account.csr
openssl x509 -req -in service-account.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out service-account.crt -days 1000


for instance in master-1 master-2; do
  scp ca.crt ca.key kube-apiserver.key kube-apiserver.crt \
    service-account.key service-account.crt \
    etcd-server.key etcd-server.crt \
    ${instance}:~/
done


