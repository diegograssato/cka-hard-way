#!/usr/bin/env bash
 
# Directory to store images
_IMAGES="/var/lib/libvirt/images"

_DISK_MAX_LIMIT_IN_GB=100
_DISK_MIN_LIMIT_IN_GB=4

_VCPU_MAX_LIMIT="$(grep processor /proc/cpuinfo -c)"

_MEMORY_LIMIT="$(awk '/MemTotal/ {printf( "%.2d\n", $2 / 1024 )}' /proc/meminfo)"

# Load environment
source "$(pwd)/enviroment.bash"

# Location of cloud image
_MACHINE_IMAGE="${_IMAGES}/${_ISO}" 

_STORAGE_PATH="$PWD"
_INSTANCE_PATH="${_STORAGE_PATH}/instances"

## NETWORK
# Bridge for VMs
_EXTERNAL_BRIDGE="vswitch_lan"
_EXTERNAL_BRIDGE_MASK="255.255.255.0"

_INTERNAL_BRIDGE="vswitch_int"
_INTERNAL_BRIDGE_MASK="255.255.255.0"

_INTERNAL_BRIDGE_GW=$(ip -4 -o addr show dev ${_INTERNAL_BRIDGE}| awk '{split($4,a,"/");print a[1]}') 
_DNS=$(wget http://ipecho.net/plain -O - -q ; echo)
_DNS="8.8.8.8"
#===========================================
# Váriavies com as Cores
#===========================================
NONE="\033[0m" # Eliminar as Cores, deixar padrão)
 
## Efeito Negrito (bold) e cores
BK="\033[1;30m" # Bold+Black (Negrito+Preto)
BR="\033[1;31m" # Bold+Red (Negrito+Vermelho)
BG="\033[1;32m" # Bold+Green (Negrito+Verde)
BY="\033[1;33m" # Bold+Yellow (Negrito+Amarelo)
BB="\033[1;34m" # Bold+Blue (Negrito+Azul)
BM="\033[1;35m" # Bold+Magenta (Negrito+Vermelho Claro)
BC="\033[1;36m" # Bold+Cyan (Negrito+Ciano - Azul Claro)
BW="\033[1;37m" # Bold+White (Negrito+Branco

_ZENITY_SUPPORT=$(which zenity)

# if [ -n "${_ZENITY_SUPPORT}" ]; then
#     echo " Tem suport"
#     else
#     echo " Num tem"

# fi

function _info() {

    local _INFO=${1:-INFORMATION}
    echo -e "${BY}$(date +"%d-%m-%Y %H:%M:%S") ~> ${_INFO} ${NONE}" 
}

function _sucess() {

    local _SUCESS=${1:-SUCESS}
    
    if [ -n "${_ZENITY_SUPPORT}" ]; then
        local _S=$(echo "${_SUCESS}" |awk '{print length}')
        local _W=$(((${_S} * 5) * 90 / ${_S}))         
        local _H=$(((${_S} * 2) * 60 / ${_S}))         
        zenity --info --width="${_W}" --height="${_H}" --text "${_SUCESS}"
         
    else
        echo -e "${BG}$(date +"%d-%m-%Y %H:%M:%S") ~> ${_SUCESS} ${NONE}"
         
    fi
}
function _warning() {

    local _WAR=${1:-WARNING}
 
    echo -e "${BR}$(date +"%d-%m-%Y %H:%M:%S") ~> ${_WAR} ${NONE}"
}

function _error() {

    local _ERR=${1:-ERROR}
 
    if [ -n "${_ZENITY_SUPPORT}" ]; then
        local _S=$(echo "${_ERR}" |awk '{print length}')
        local _W=$(((${_S} * 5) * 90 / ${_S}))         
        local _H=$(((${_S} * 2) * 60 / ${_S}))         
        zenity --error --width="${_W}" --height="${_H}" --text "${_ERR}"
         
    else
        echo -e "${BR}$(date +"%d-%m-%Y %H:%M:%S") ~> ${_ERR} ${NONE}"
         
    fi
}

# Validate informations
function _validate_initial_configurations() {
    if [ ! -f "${_INVENTORIES_FILE}" ]; then
        _error "Inventories provide [ ${_INVENTORIES_FILE} ] not found!"
        exit 1;
    fi

    if [ ! -f "${_MACHINE_IMAGE}" ]; then
        _error "Machine image provide [ ${_MACHINE_IMAGE} ] not found!"
        exit 1;
    fi
}
# Call validation
_validate_initial_configurations

function _check_machine_exists() {
    
    local _MACHINE_NAME=${1}  
    virsh dominfo "${_MACHINE_NAME}" > /dev/null 2>&1
}

function _check_machine_already_exists() {
    
    local _MACHINE_NAME=${1} 
    _info "Check if machine already exists..."
    _check_machine_exists "${_MACHINE_NAME}"
}

function _check_machine_already_exists_and_exit() {
    
    local _MACHINE_NAME=${1}

    _check_machine_exists "${_MACHINE_NAME}"
    if [ "$?" -eq 0 ]; then
        _warning "${_MACHINE_NAME} already exists.  "
        exit 1
    fi
}

# Get machines by host group
function _get_machines() {

    local _HOST_GROUP=${1:-master}
    
    HOSTS=$(ansible -i ${_INVENTORIES_FILE} ${_HOST_GROUP} --list-hosts -o |sed -n '1!p')
    echo ${HOSTS}
} 
 

# Check if domain already exists
function _delete_machine() {

    local _MACHINE_NAME=${1}
    _validate_machine_name "${_MACHINE_NAME}"

    local _MACHINE_SOURCE_PATH="${_INSTANCE_PATH}/${_MACHINE_NAME}"
     
    _check_machine_already_exists "${_MACHINE_NAME}"
    if [ "$?" -eq 0 ]; then
        _info "Destroying the machine ${_MACHINE_NAME} (if it exists)..."  

        # Remove domain with the same name
        virsh destroy "${_MACHINE_NAME}"
        sleep 1;

        _info "Undefing the machine ${_MACHINE_NAME} (if it exists)..." 
        virsh undefine "${_MACHINE_NAME}"
        if [[ -d "${_MACHINE_SOURCE_PATH}" ]]; then
            _info "Files found for ${_MACHINE_NAME} machine, remote it!" 
            rm -rf "${_MACHINE_SOURCE_PATH}"
        fi
        sleep 1;
    else
        _warning "Machine ${_MACHINE_NAME} not found!"
    fi
   
}
 


function _delete_group_machines() {
    clear
    local _HOST_GROUP=${1}
    _validate_machine_name "${_HOST_GROUP}"
    
    for _MACHINE in $(_get_machines ${_HOST_GROUP:?});do

        _delete_machine "${_MACHINE}"

    done
}        

function _get_machine_atributes() {
        
    local _MACHINE_NAME=${1}
    local _INTERFACE=${2} 
    
    # Validate machine interface
    local _GET_REAL_IP=$(grep -w "${_MACHINE_NAME}" "${_INVENTORIES_FILE}"| grep -Po "${_INTERFACE}=[^\s]+"|cut -d "=" -f2) 

    echo "${_GET_REAL_IP:-}"    
       
}

function _validate_machine_name() {
        
    local _MACHINE_NAME=${1}
    
    #Name validation
    [[ -z "${_MACHINE_NAME}" ]] && \
        _error "Plase informe the machine group or machine name.\n" && exit 1; 
}


function _validate_network_information() {
        
    local _MACHINE_NAME=${1}
    local _INTERFACE=${2}  
    
    # Check network configuration       
    local _BRIDGE_IP=$(_get_machine_atributes "${_MACHINE_NAME}" "${_INTERFACE}")
    [[ -z "${_BRIDGE_IP}" ]] && \
        _error "[ ${_MACHINE_NAME} ] Check network configuration in [ ${_INTERFACE} ] atribute.\n" && exit 1; 

    # Check IP exists
    local _CHECK_BRIDGE_IP=$(grep -v "${_MACHINE_NAME}" "${_INVENTORIES_FILE}"| grep -w -o "${_INTERFACE}=${_BRIDGE_IP}")
    [[ -n "${_CHECK_BRIDGE_IP}" ]] && \
        _error "[ ${_MACHINE_NAME} ] IP '${_BRIDGE_IP}' for [ ${_INTERFACE} ] interface allready in uso.\n" && exit 1; 
        
}


function _validate_memory_information() {
        
    local _MACHINE_NAME=${1}
    local _MACHINE_MEMORY=${2} 
    
    #Memory validation         
    [[ "${_MEMORY_LIMIT}" -le  "${_MACHINE_MEMORY}"  ]] && \
        _error "The memory from '${_MACHINE_NAME}' must be less than ${_MEMORY_LIMIT}.\n" && exit 1;
    
    [[ "${_MACHINE_MEMORY}" -lt 1000 ]] && \
        _error "The memory from '${_MACHINE_NAME}' must be greater than 1000MB.\n" && exit 1;
     
}

function _validate_vcpu_information() {
        
    local _MACHINE_NAME=${1}
    local _MACHINE_VCPUS=${2} 
    
    #VCPU validation
    [[ "${_MACHINE_VCPUS}" -gt "${_VCPU_MAX_LIMIT}"  ]] && \
        _error "The vcpu from '${_MACHINE_NAME}' must be less than ${_VCPU_MAX_LIMIT}.\n" && exit 1;

    [[ 0 -ge "${_MACHINE_VCPUS}" ]] && \
        _error "The vcpu from '${_MACHINE_NAME}' must be greater than 0.\n" && exit 1;
}

function _validate_disk_information() {
        
    local _MACHINE_NAME=${1}
    local _MACHINE_DISK=${2} 
    
    #Disk validation 
    [[ "${_DISK_MIN_LIMIT_IN_GB}" -ge  "${_MACHINE_DISK}"  ]] && \
        _error "The disk from '${VM_NAME}' must be less than ${_DISK_MIN_LIMIT_IN_GB}.\n" && exit 1;

    [[ "${_DISK_MAX_LIMIT_IN_GB}" -lt "${_MACHINE_DISK}" ]] && \
        _error "The disk from '${_MACHINE_NAME}' must be greater than ${_DISK_MAX_LIMIT_IN_GB}.\n" && exit 1;
}

function _validate_ssh_port() {
        
    local _MACHINE_NAME=${1}
    local _SSH_PORT=${2} 
    
    #Port validation 
    [[ 0 -ge "${_SSH_PORT}" ]] && \
        _error "The ssh port from '${_MACHINE_NAME}' must be greater than 0.\n" && exit 1;

    [[ 10000 -lt "${_SSH_PORT}" ]] && \
        _error "The ssh port from '${_MACHINE_NAME}' must be less than 10000.\n" && exit 1;
}

function _validate_parameters() {
        
        local VM_NAME=${1}
        local _MACHINE_NAME=${1} 
 
        _info "INSTANCE LOCALTION: ${_MACHINE_SOURCE_PATH}"

        # Get network information
        local _USER=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_user")
        export _MACHINE_USER=${_USER:-root}
        _info "ADMIN USER: ${_MACHINE_USER}"

        local _PASSWORD=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_password")
        export _MACHINE_PASSWORD=${_PASSWORD:-passw0rd}
        _info "ADMIN PASSWORD: ${_MACHINE_PASSWORD}"

        export _MACHINE_MEMORY=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_mem")         
        _validate_memory_information "${_MACHINE_NAME}" "${_MACHINE_MEMORY}"
        _info "MEMORY: ${_MACHINE_MEMORY}MB"

        export _MACHINE_VCPUS=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_cpu")
        _validate_vcpu_information "${_MACHINE_NAME}" "${_MACHINE_VCPUS}"
        _info "CPUS: ${_MACHINE_VCPUS} VCPUs"

        export _MACHINE_DISK=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_disk")
        _validate_disk_information "${_MACHINE_NAME}" "${_MACHINE_DISK}" 
        _info "DISK 1: ${_MACHINE_DISK}GB\n"
        
        _info "NETWORK INFORMATION"
        local _SSH_PORT=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_port")        
        export _MACHINE_SSH_PORT=${_SSH_PORT:-22}
        _validate_ssh_port "${_MACHINE_NAME}" "${_MACHINE_SSH_PORT}"
        _info "SSH PORT: ${_SSH_PORT}"

        export _INTERNAL_BRIDGE_IP=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_host")
        _validate_network_information "${_MACHINE_NAME}" "ansible_host"
         _info "INTERNAL IP: ${_INTERNAL_BRIDGE}: ${_INTERNAL_BRIDGE_IP}"
        
        local _EXT_BRIDGE_IP=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_external_host")
        if [ -n "${_EXT_BRIDGE_IP}" ]; then
            export _EXTERNAL_BRIDGE_IP=${_EXT_BRIDGE_IP}
            _validate_network_information "${_MACHINE_NAME}" "ansible_external_host"
            _info "EXTERNAL IP: ${_EXTERNAL_BRIDGE}: ${_EXTERNAL_BRIDGE_IP}"
        fi

        local _SSH_KEY=$(_get_machine_atributes "${_MACHINE_NAME}" "ansible_ssh_private_key_file")

        if [ -s "${_SSH_KEY}" ]; then
            export _MACHINE_SSH_KEY=$(cat ${_SSH_KEY})
        else
            if [ -s "${HOME}/.ssh/id_rsa.pub" ]; then
                export _MACHINE_SSH_KEY=$(cat ${HOME}/.ssh/id_rsa.pub)
                _info "Loading ssh via key: ${HOME}/.ssh/id_rsa.pub"
            fi
        fi
         
}


function _create_template_vm() {

    local _MACHINE_NAME=${1}    
     
    local _MACHINE_SOURCE_PATH="${_INSTANCE_PATH}/${_MACHINE_NAME}"
    [[ -d "${_MACHINE_SOURCE_PATH}" ]] && _info "Cleaning up files for ${_MACHINE_NAME} machine ..." && rm -rf "${_MACHINE_SOURCE_PATH:?}"
    
    # Cloud init files
    _CD_ISO_PATH="${_MACHINE_SOURCE_PATH}/${_MACHINE_NAME}-cidata.iso"
    _CONFIG2="${_MACHINE_SOURCE_PATH}/config-2"
    _USER_DATA="${_CONFIG2}/user-data"
    _META_DATA="${_CONFIG2}/meta-data"
    _NETWORK_DATA="${_CONFIG2}/network-config"    
    [[ ! -d  "${_CONFIG2}" ]] && mkdir -p "${_CONFIG2}"     

    # Set disk path
    _DISK="${_MACHINE_SOURCE_PATH}/${_MACHINE_NAME}.qcow2"

    # Get timezone
    _TIMEZONE=$(cat /etc/timezone)
    _info "Get timezone: ${_TIMEZONE}" 
    
    _info "Creating instance path ${_MACHINE_SOURCE_PATH}"
    mkdir -p "${_MACHINE_SOURCE_PATH}"
    _info "Copying disk ${_MACHINE_SOURCE_PATH}"
    cp -a "${_MACHINE_IMAGE}" "${_DISK}"
    touch "${_CD_ISO_PATH}"

    _validate_parameters "${_MACHINE_NAME}"

    
    
pushd "${_MACHINE_SOURCE_PATH}" > /dev/null  
    
    # Generate user_data file configuration 
    _create_user_data
    # Generate meta_data file configuration 
    _create_metadata
    
    _info "Copying template image and resize it..."
    _info "INFO: qemu-img resize ${_DISK}  ${_MACHINE_DISK}GB"  
    #   sudo apt-get install qemu-utils
    qemu-img resize "${_DISK}" "${_MACHINE_DISK}G" > /dev/null
 
    _info "Installing the domain and adjusting the configuration..."

    local _VIRSH_CMG="virt-install --name ${_MACHINE_NAME} \
            --boot loader=/var/lib/libvirt/images/bios \
            --ram ${_MACHINE_MEMORY} \
            --vcpus ${_MACHINE_VCPUS} \
            --import \
            --cpu host-passthrough \
            --disk ${_DISK},device=disk,bus=scsi,discard=unmap,boot_order=1 \
            --disk ${_CD_ISO_PATH},device=cdrom,device=cdrom,perms=ro,bus=sata,boot_order=2 \
            --network bridge=${_INTERNAL_BRIDGE},model=virtio,virtualport_type=openvswitch \
            --clock hypervclock_present=yes \
            --controller type=scsi,model=virtio-scsi \
            --noautoconsole \
            --noapic \
            --accelerate \
            --graphics spice"

    if [[ -n ${_EXTERNAL_BRIDGE_IP} ]]; then
        _VIRSH_CMG=$(echo "${_VIRSH_CMG}" | xargs -i -- echo  {} --network bridge="${_EXTERNAL_BRIDGE}",model=virtio,virtualport_type=openvswitch)
    fi

    ${_VIRSH_CMG} --print-xml > "${_MACHINE_NAME}.xml"
  
    _info "Define machine ${_MACHINE_NAME}.xml."
    virsh define "${_MACHINE_NAME}.xml" >/dev/null


    MACS=$(virsh domiflist "${_MACHINE_NAME}"|grep -w -o -E "([0-9a-f]{2}:){5}([0-9a-f]{2})")
    MAC_COUNT=1
    for MAC in $MACS; do
      eval "MAC_$MAC_COUNT"="${MAC}"
     
      let  MAC_COUNT++
    done

    # Generate network_data file configuration 
    _create_network_data2
    
    # Create CD-ROM ISO with cloud-init config
    _info "Generating ISO for cloud-init..."
    genisoimage -output "${_CD_ISO_PATH}" -volid cidata -joliet -rock "${_CONFIG2}" &>/dev/null
 
      
popd > /dev/null
 
}

function _check_machine_is_alive() {

    local _MACHINE_NAME=${1}
    local _FAILS=0   
    while true; do
        
        # Check if the machine is already accessible.
        ping -c 1 "${_INTERNAL_BRIDGE_IP}" >/dev/null 2>&1
        if [[ "$?" -ne 0 ]] ; then #if ping exits nonzero...
            _FAILS=$((FAILS + 1))
            _info "INFO: Checking if server ${_MACHINE_NAME} with IP ${_INTERNAL_BRIDGE_IP} is online. (${_FAILS} out of 20)" 
        fi

        # Check if the machine can already be accessed via SSH
        nc -z -v -w5 "${_INTERNAL_BRIDGE_IP}" "${_MACHINE_SSH_PORT}" >/dev/null 2>&1
        if [[ "$?" -ne 0 ]] ; then #if wc exits nonzero...
            _FAILS=$((_FAILS + 1))
            _info "INFO: Checking if SSH server is online on ${_MACHINE_NAME}(${_INTERNAL_BRIDGE_IP})"         
        else
             
            break;
        fi

        # Fixed the problem with provisioning VM
        if [[ "${_FAILS}" -gt 20 ]]; then
            _warning "INFO: Server is still offline after 20min. I will end here!"
            return 100;
        fi
        sleep 2;
    done
}

function _finalize_machine_creation() {

    local _MACHINE_NAME=${1}
     
    # Detach cdrom    
    _info "Detach cdrom ${_CD_ISO_PATH}."  
    # At the next boot, the cdrom will be removed."
    virsh detach-disk "${_MACHINE_NAME}" "${_CD_ISO_PATH}" --config
    if [ $? -eq 0 ] ; then
        _info "Removing metadata ISO ${_CD_ISO_PATH}."
        rm -rf "${_CD_ISO_PATH:?}"      
    fi

    # Remove the unnecessary cloud init files
    _info "Cleaning up cloud-init..."
    rm -rf "${_CONFIG2:?}" 

    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${_INTERNAL_BRIDGE_IP}"  >/dev/null 2>&1

    if [[ -n ${_EXTERNAL_BRIDGE_IP} ]]; then
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${_EXTERNAL_BRIDGE_IP}"  >/dev/null 2>&1
    fi

    _info "Done connect via ssh using ${_MACHINE_USER}@${_MACHINE_NAME} and password ${_MACHINE_PASSWORD}.\n" 
}

function _create_machine() {

    local _MACHINE_NAME=${1}
    _validate_machine_name "${_MACHINE_NAME}"
   
   _check_machine_exists "${_MACHINE_NAME}"
    if [ "$?" -eq 0 ]; then
        
    _warning "${_MACHINE_NAME} already exists.  "
        read -p "Do you want to overwrite ${_MACHINE_NAME} [y/N]? " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            
            # Remove domain with the same name
            _delete_machine "${_MACHINE_NAME}"
        else
            return 100;
        fi
    fi

    _create_template_vm "${_MACHINE_NAME}"

    _info "Start ${_MACHINE_NAME} machine."
    
    virsh start "${_MACHINE_NAME}" >/dev/null 2>&1
    
    _check_machine_is_alive "${_MACHINE_NAME}"
    # if [ "$?" -eq 100 ]; then
            
    #     continue;
    # fi

    _finalize_machine_creation "${_MACHINE_NAME}"  
}


function _create_hosts_group() {

    clear
    local _HOST_GROUP="${1}"
    _validate_machine_name "${_HOST_GROUP}"

    for _MACHINE_NAME in $(_get_machines ${_HOST_GROUP:?}); do

        _create_machine "${_MACHINE_NAME}"
        if [ "$?" -eq 100 ]; then
            
            continue;
        fi
    done
 
}


OPERATION="${1}"
shift 1;
case "${OPERATION}" in
	create|all|create-all)
        _create_hosts_group "${1}"
	;;

    new|n)
        _create_machine "${1}"
	;;

	delete|destroy|d)
		_delete_machine "${1}"
	;;

	delete-group|dg|dall)
	    _delete_group_machines "${1}"
	;;

	*)
        echo "Sorry, I don't understand!"
    ;;
  esac
 