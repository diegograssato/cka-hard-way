#!/usr/bin/env bash

#ISO="${IMAGES}/CentOS-6-x86_64-GenericCloud.qcow2"
#ISO="${IMAGES}/CentOS-7-x86_64-GenericCloud.qcow2"
#https://cloud-images.ubuntu.com/releases/disco/release/ubuntu-19.04-server-cloudimg-amd64.img
_ISO=ubuntu-19.04-server-cloudimg-amd64.img
_INVENTORIES_FILE="$(pwd)/inventories/hosts" 

DOMAIN="dtux.lan"
UUID="$(uuidgen)" 

function _create_metadata() {
    cat > ${_META_DATA} << _EOF_
instance-id: ${UUID}-${_MACHINE_NAME}
local-hostname: ${_MACHINE_NAME}
_EOF_

}

function _create_user_data() {

    # Generate user_data file configuration
    cat > "${_USER_DATA}" << _EOF_
#cloud-config
datasource_list: ['ConfigDrive']
disable_ec2_metadata: true 
# Hostname management
preserve_hostname: False
hostname: ${_MACHINE_NAME}
fqdn: ${_MACHINE_NAME}.${DOMAIN}
timezone: "${_TIMEZONE}"

bootcmd:
   - echo "nameserver ${_DNS}" > /etc/resolv.conf
   - echo "domain ${DOMAIN}" >> /etc/resolv.conf
   - echo "${_INTERNAL_BRIDGE_IP}   ${_MACHINE_NAME}    ${_MACHINE_NAME}.${DOMAIN}" >> /etc/hosts

users:
  - name: ${_MACHINE_USER}
    lock-passwd: false
    plain_text_passwd: '${_MACHINE_PASSWORD}'
    ssh-authorized-keys:
      - ${_MACHINE_SSH_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
  - name: root
    ssh_pwauth: True
    lock-passwd: false
    plain_text_passwd: '${_MACHINE_PASSWORD}'
    ssh-authorized-keys: 
      - ${_MACHINE_SSH_KEY}
 
# Remove cloud-init when finished with it
runcmd:
   - sed -i -e '/^#PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
   - sed -i -e 's/#DNS=/DNS=${_DNS}/' /etc/systemd/resolved.conf
   - sed -i -e 's/#Domains=/Domains=${DOMAIN}/' /etc/systemd/resolved.conf
   - rm -f /etc/resolv.conf
   - ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
   - [ service, systemd-resolved, restart]
   - [ apt-get, -y, remove, cloud-init ]
   
   
package_update: true
package_upgrade: true

final_message: "The cluster system is finally up"  

_EOF_


} 

function _create_network_data2() {

  _create_head >/dev/null 2>&1
  _create_interface eth0 ${MAC_1} ${_INTERNAL_BRIDGE_IP} ${_INTERNAL_BRIDGE_MASK} >/dev/null 2>&1
  _create_network_routers >/dev/null 2>&1
  _create_interface eth1 ${MAC_2} ${_EXTERNAL_BRIDGE_IP} ${_EXTERNAL_BRIDGE_MASK} >/dev/null 2>&1

}

function _create_head(){
  cat << EOF | tee ${_NETWORK_DATA}
---
version: 1
config:
  - type: nameserver
    address: [ ${_DNS}  ]
    search: [${_MACHINE_NAME}.${DOMAIN}]  
EOF
}

function _create_network_routers(){
  cat << EOF | tee -a ${_NETWORK_DATA}
        routes:
          - network: 0.0.0.0
            netmask: 0.0.0.0
            gateway: ${_INTERNAL_BRIDGE_GW} 
EOF
}

function _create_interface(){

  local _INT=${1}
  local _MAC=${2}
  local _IP=${3}
  local _MASK=${4}
  cat << EOF | tee -a ${_NETWORK_DATA}
  - type: physical
    name: ${_INT}
    mac_address: ${_MAC}
    subnets:
      - type: static
        address: ${_IP}
        netmask: ${_MASK}  
EOF
}