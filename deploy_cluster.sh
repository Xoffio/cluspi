#!/bin/bash

# DEFAULT VARS
IS_DESTROY=0
K3S_VER="1.32.5+k3s1"
K3S_DATASTORE="etcd"
MAIN_CONTROL_KUBEPORT="6443"
METALLB_VER="0.15.2"
RANCHER_VER="3.18.3"
CERT_MANAGER_VER="1.18.1"
RANCHER_N_REPLICAS=1

terraform_var_file="./terraform-proxmox/terraform.tfvars"
ansible_var_file="./k3s-cluster/group_vars/all.yml"
ansible_host_file="./k3s-cluster/inventory/hosts.yml"

source ./scripts/ansible_templates.sh
source ./scripts/ansible_fns.sh
source ./scripts/terraform_templates.sh
source ./scripts/terraform_fns.sh

display_help() {
	echo "Usage: $(basename "$0") [OPTIONS]"
	echo
	echo "Options:"
	echo "  -d, --destroy     Destroy the cluster and clean up resources."
	echo "  -h, --help        Show this help message and exit."
	echo
	echo "Examples:"
	echo "  $(basename "$0")           # Run the script normally (e.g., deploy)"
	echo "  $(basename "$0") --destroy # Destroy the deployed cluster"
	echo "  $(basename "$0") --help    # Show this help message"
	exit 1
}

# Process command line arguments
while [ "$1" != "" ]; do
	case $1 in
	--destroy | -d)
		IS_DESTROY=1
		;;
	--help | -h)
		display_help
		;;
	*)
		echo "Error: Unknown option '$1'."
		display_help
		;;
	esac
	shift
done

# Load .env variables
if [ -f .env ]; then
	while IFS='=' read -r key value; do
		# Skip blank lines and full-line comments
		[[ -z "$key" || "$key" =~ ^# ]] && continue

		# Remove inline comment from value (only if preceded by space)
		value="${value%%[[:space:]]\#*}"

		export "$key=$value"
	done <.env
else
	echo ".env file not found!"
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

##  ______________________________________
## |              Terraform              |
## |_____________________________________|
create_terraform_vars_file

##  ______________________________________
## |               Ansible               |
## |_____________________________________|
create_ansible_vars_file
create_ansible_hosts_file
check_ssh_connection

##  ______________________________________
## |              DEPLOYMENT             |
## |_____________________________________|

if [ "$IS_DESTROY" -eq 0 ]; then
	create_python_venv
	deploy_vms
	activate_python_venv
	ansible-playbook k3s-cluster/playbook.yml -i k3s-cluster/inventory/hosts.yml
else
	destroy_vms
fi
