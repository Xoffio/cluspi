#!/bin/bash

# DEFAULT VARS
NUM_CONTROL_NODES=3
NUM_WORKER_NODES=1
CONTROL_NODE_NAME="control"
CONTROL_NODE_CORES=2
CONTROL_NODE_DISK_SIZE=32
CONTROL_NODE_RAM_SIZE=2048
WORKER_NODE_NAME="worker"
WORKER_NODE_CORES=1
WORKER_NODE_DISK_SIZE=32
WORKER_NODE_RAM_SIZE=1024
CONTROL_NODE_LB_NAME="control-lb"
K3S_VER="1.32.5+k3s1"
K3S_DATASTORE="etcd"
MAIN_CONTROL_KUBEPORT="6443"
METALLB_VER="0.15.2"
RANCHER_VER="3.18.3"
CERT_MANAGER_VER="1.18.1"
RANCHER_N_REPLICAS=1

format_ips_for_tfvars() {
	local var_name="$1"
	local ip_list="$2"
	local padding="$3"

	IFS=',' read -ra IPS <<<"$ip_list"
	local formatted_ips
	formatted_ips=$(printf '"%s", ' "${IPS[@]}")
	formatted_ips="[${formatted_ips%, }]"

	printf "%s%*s%s\n" "$var_name" "$padding" "" "= $formatted_ips"
}

# Load .env variables
if [ -f .env ]; then
	export $(grep -v '^#' .env | xargs)
else
	echo ".env file not found!"
	exit 1
fi

terraform_var_file="./terraform-proxmox/terraform.tfvars"
ansible_var_file="./k3s-cluster/group_vars/all.yml"
ansible_host_file="./k3s-cluster/inventory/hosts.yml"

##  ______________________________________
## |          Terraform Variables        |
## |_____________________________________|

: "${NUM_CONTROL_NODES:?NUM_CONTROL_NODES is required}"
: "${NUM_WORKER_NODES:?NUM_WORKER_NODES is required}"
: "${PM_API_URL:?PM_API_URL is required}"
: "${PM_API_TOKEN_ID:?PM_API_TOKEN_ID is required}"
: "${PM_API_TOKEN_SECRET:?PM_API_TOKEN_SECRET is required}"

: "${CONTROL_NODE_NAME:?CONTROL_NODE_NAME is required}"
: "${CONTROL_NODE_IPS:?CONTROL_NODE_IPS is required}"
: "${CONTROL_NODE_PROX_TARGET_NODE:?CONTROL_NODE_PROX_TARGET_NODE is required}"

: "${WORKER_NODE_NAME:?WORKER_NODE_NAME is required}"
: "${WORKER_NODE_IPS:?WORKER_NODE_IPS is required}"
: "${WORKER_NODE_PROX_TARGET_NODE:?WORKER_NODE_PROX_TARGET_NODE is required}"

: "${CONTROL_NODE_LB_NAME:?CONTROL_NODE_LB_NAME is required}"
: "${CONTROL_NODE_LB_IPS:?CONTROL_NODE_LB_IPS is required}"
: "${CONTROL_NODE_LB_PROX_TARGET_NODE:?CONTROL_NODE_LB_PROX_TARGET_NODE is required}"

: "${TEMPLATE_NAME:?TEMPLATE_NAME is required}"
: "${STORAGE_NAME:?STORAGE_NAME is required}"
: "${GATEWAY_IP:?GATEWAY_IP is required}"
: "${DNS_IP:?DNS_IP is required}"
: "${VM_USER:?VM_USER is required}"
: "${GITHUB_USER:?GITHUB_USER is required}" # TODO: What if the user doesn't have their keys in Github. Fix this

echo "num_control_nodes   = ${NUM_CONTROL_NODES}" >"$terraform_var_file"
echo "num_worker_nodes    = ${NUM_WORKER_NODES}" >>"$terraform_var_file"
echo "pm_api_url          = \"${PM_API_URL}\"" >>"$terraform_var_file"
echo "pm_api_token_id     = \"${PM_API_TOKEN_ID}\"" >>"$terraform_var_file"
echo "pm_api_token_secret = \"${PM_API_TOKEN_SECRET}\"" >>"$terraform_var_file"

echo "" >>"$terraform_var_file"
echo "control_node_name             = \"${CONTROL_NODE_NAME}\"" >>"$terraform_var_file"
echo "control_node_cores            = ${CONTROL_NODE_CORES}" >>"$terraform_var_file"
echo "control_node_disk_size        = ${CONTROL_NODE_DISK_SIZE}" >>"$terraform_var_file"
echo "control_node_ram_size         = ${CONTROL_NODE_RAM_SIZE}" >>"$terraform_var_file"

format_ips_for_tfvars "control_node_ips" "$CONTROL_NODE_IPS" "14" >>"$terraform_var_file"
format_ips_for_tfvars "control_node_prox_target_node" "$CONTROL_NODE_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
IFS=',' read -ra CONTROL_NODE_IPS <<<"$CONTROL_NODE_IPS"

echo "" >>"$terraform_var_file"
echo "worker_node_name             = \"${WORKER_NODE_NAME}\"" >>"$terraform_var_file"
echo "worker_node_cores            = ${WORKER_NODE_CORES}" >>"$terraform_var_file"
echo "worker_node_disk_size        = ${WORKER_NODE_DISK_SIZE}" >>"$terraform_var_file"
echo "worker_node_ram_size         = ${WORKER_NODE_RAM_SIZE}" >>"$terraform_var_file"
format_ips_for_tfvars "worker_node_ips" "$WORKER_NODE_IPS" "14" >>"$terraform_var_file"
format_ips_for_tfvars "worker_node_prox_target_node" "$WORKER_NODE_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
IFS=',' read -ra WORKER_NODE_IPS <<<"$WORKER_NODE_IPS"

echo "" >>"$terraform_var_file"
echo "control_node_lb_name             = \"${CONTROL_NODE_LB_NAME}\"" >>"$terraform_var_file"
format_ips_for_tfvars "control_node_lb_ips" "$CONTROL_NODE_LB_IPS" "14" >>"$terraform_var_file"
format_ips_for_tfvars "control_node_lb_prox_target_node" "$CONTROL_NODE_LB_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
IFS=',' read -ra CONTROL_NODE_LB_IPS <<<"$CONTROL_NODE_LB_IPS"

echo "" >>"$terraform_var_file"
echo "template_name = \"$TEMPLATE_NAME\"" >>"$terraform_var_file"
echo "storage_name  = \"$STORAGE_NAME\"" >>"$terraform_var_file"
echo "gateway_ip    = \"$GATEWAY_IP\"" >>"$terraform_var_file"
echo "dns_ip        = \"$DNS_IP\"" >>"$terraform_var_file"
echo "vm_user       = \"$VM_USER\"" >>"$terraform_var_file"
echo "github_user   = \"$GITHUB_USER\"" >>"$terraform_var_file"

##  ______________________________________
## |          Ansible Variables          |
## |_____________________________________|

: "${K3S_VER:?K3S_VER is required}"
: "${K3S_DATASTORE:?K3S_DATASTORE is required}"

: "${MAIN_CONTROL_KUBEPORT:?MAIN_CONTROL_KUBEPORT is required}"
: "${CONTROL_LB_VIRTUAL_IP:?CONTROL_LB_VIRTUAL_IP is required}"

: "${METALLB_VER:?METALLB_VER is required}"
: "${METALLB_IP_RANGE:?METALLB_IP_RANGE is required}"

: "${RANCHER_VER:?RANCHER_VER is required}"
: "${CERT_MANAGER_VER:?CERT_MANAGER_VER is required}"
: "${RANCHER_HOSTNAME:?RANCHER_HOSTNAME is required}"
: "${RANCHER_N_REPLICAS:?RANCHER_N_REPLICAS is required}"
: "${RANCHER_FQDN:?RANCHER_FQDN is required}"

echo "k3s_ver: \"$K3S_VER\"" >"$ansible_var_file"
echo "k3s_datastore: \"$K3S_DATASTORE\"" >>"$ansible_var_file"
echo "" >>"$ansible_var_file"

echo "main_control_kubeport: \"$MAIN_CONTROL_KUBEPORT\"" >>"$ansible_var_file"
echo "control_lb_virtual_ip: \"$CONTROL_LB_VIRTUAL_IP\"" >>"$ansible_var_file"
echo "" >>"$ansible_var_file"

echo "metallb_ver: \"$METALLB_VER\"" >>"$ansible_var_file"
echo "metallb_ip_range: \"$METALLB_IP_RANGE\"" >>"$ansible_var_file"
echo "" >>"$ansible_var_file"

echo "rancher_ver: \"$RANCHER_VER\"" >>"$ansible_var_file"
echo "cert_manager_ver: \"$CERT_MANAGER_VER\"" >>"$ansible_var_file"
echo "rancher_hostname: \"$RANCHER_HOSTNAME\"" >>"$ansible_var_file"
echo "rancher_n_replicas: \"$RANCHER_N_REPLICAS\"" >>"$ansible_var_file"
echo "rancher_fqdn: \"$RANCHER_FQDN\"" >>"$ansible_var_file"
echo "" >>"$ansible_var_file"

##  ______________________________________
## |            Ansible Hosts            |
## |_____________________________________|

echo "[main_control]" >"${ansible_host_file}"
echo "main-node ansible_host=${CONTROL_NODE_IPS[0]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
echo "" >>"${ansible_host_file}"

echo "[control_nodes]" >>"${ansible_host_file}"
for ((n_node = 1; n_node < ${#CONTROL_NODE_IPS[@]}; n_node++)); do
	echo "control-node-${n_node} ansible_host=${CONTROL_NODE_IPS[n_node]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
done
echo "" >>"${ansible_host_file}"

echo "[worker_nodes]" >>"${ansible_host_file}"
for ((n_node = 0; n_node < ${#WORKER_NODE_IPS[@]}; n_node++)); do
	echo "worker-node-${n_node+1} ansible_host=${WORKER_NODE_IPS[n_node]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
done
echo "" >>"${ansible_host_file}"

echo "[control_load_balancer]" >>"${ansible_host_file}"
echo "lb-1 ansible_host=${CONTROL_NODE_LB_IPS[0]%/*} ansible_user=${VM_USER} keepalived_state=MASTER keepalived_priority=200 ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
echo "lb-2 ansible_host=${CONTROL_NODE_LB_IPS[1]%/*} ansible_user=${VM_USER} keepalived_state=BACKUP keepalived_priority=100 ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
