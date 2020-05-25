cat << END > startup-script.sh
#cloud-config
datasource_list: ['ConfigDrive']
disable_ec2_metadata: true 
timezone: "America/Sao_Paulo"

users:
  - name: ubuntu
    lock-passwd: false
    plain_text_passwd: 'passw0rd'
    ssh-authorized-keys:
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
  - name: ${ADMIN_USER}
    ssh_pwauth: True
    lock-passwd: false
    plain_text_passwd: 'passw0rd'
 
# Remove cloud-init when finished with it
runcmd:
   - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
 
final_message: "The system is finally up"  
END

kubectl create secret generic my-vmi-secret --from-file=userdata=startup-script.sh


kubectl plugin pvc create ubuntu1604 1Gi $PWD/ubuntu-16.04-server-cloudimg-amd64-disk1.img disk.img


