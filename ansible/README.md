## Kubernetes Cluster hard way


### Apply inventories

```bash

ansible-playbook -i inventories/hosts playbook.yml


# Execute playbook with tags
ansible-playbook -i inventories/hosts playbook.yml --tags etc-status

```

### Todo List

- [x] Bootstrapping the etcd Cluster
- [x] Verification the etcd Cluster
- [x] Configure clients
- [x] Generating the Data Encryption Config and Key
- [ ] Bootstrapping the Kubernetes Control Plane
- [ ] Configure workers
- [ ] Configure load-balance
- [ ] Check if exists kvm images, if not exist download
- [ ] Check if exists kvm bios, if not exist download bios


### User guide
 
https://kubevirt.io/user-guide/#/workloads/virtual-machines/expose-service
https://www.digitalocean.com/community/tutorials/how-to-use-ansible-to-install-and-set-up-docker-on-ubuntu-18-04


### Ansible install dependencies


```bash 

# Update Repositories
sudo apt-get update

# Determine Ubuntu Version
. /etc/lsb-release

# Decide on package to install for `add-apt-repository` command
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

```