#!/bin/bash

# DEFAULT VARS
IS_DESTROY=0
IS_UNINSTALL=0
K3S_VER="1.32.5+k3s1"
K3S_DATASTORE=""
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
	echo "  -d, --datastore [ETCD|EDB|NONHA]   Specify the datastore type:"
	echo "      ETCD   - Deploys a highly available cluster using embedded etcd."
	echo "               • Requires a minimum of 3 control nodes."
	echo "               • May have performance issues on slow disks."
	echo ""
	echo "      EDB    - Deploys a cluster using an external MySQL-compatible database."
	echo "               • Can be used in both HA and non-HA configurations."
	echo "               • HA requires a minimum of 2 control nodes."
	echo ""
	echo "      NONHA  - Deploys a non-HA cluster with a single control node using embedded SQLite."
	echo ""
	echo "  -u, --uninstall                    Uninstall the Kubernetes cluster, leaving the VMs intact."
	echo "  -x, --destroy                      Destroy the cluster and clean up resources."
	echo "  -h, --help                         Show this help message and exit."
	echo
	echo "Examples:"
	echo "  $(basename "$0")           # Run the script normally (e.g., deploy)"
	echo "  $(basename "$0") --datastore ETCD    # Deploy HA cluster with embedded etcd"
	echo "  $(basename "$0") --datastore EDB     # Deploy cluster with external database"
	echo "  $(basename "$0") --destroy # Destroy the deployed cluster"
	echo "  $(basename "$0") --help    # Show this help message"
	exit 1
}

# TODO: If not HA then don't deploy load balancers

#  ____________________________________________________________
# |                     Load .env Variables                    |
# |____________________________________________________________|
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

#  ____________________________________________________________
# |                      Load CLI Parameters                   |
# |____________________________________________________________|
while [ "$1" != "" ]; do
	case $1 in
	--datastore | -d)
		shift
		K3S_DATASTORE="$1"
		;;
	--uninstall | -u)
		IS_UNINSTALL=1
		;;
	--destroy | -x)
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

#  ____________________________________________________________
# |                      Verify Variables                      |
# |____________________________________________________________|

if [ "$IS_DESTROY" -eq 0 ] && [ "$IS_UNINSTALL" -eq 0 ]; then
	if [ "$K3S_DATASTORE" != "ETCD" ] && [ "$K3S_DATASTORE" != "EDB" ] && [ "$K3S_DATASTORE" != "NONHA" ]; then
		echo "You need to set the option '--datastore'"
		display_help
	else
		if [ "$K3S_DATASTORE" == "ETCD" ] && [ "$NUM_CONTROL_NODES" -lt 3 ]; then
			echo "ETCD needs a minimum of 3 control nodes."
			display_help
		fi

		if [ "$K3S_DATASTORE" == "NONHA" ] && [ "$NUM_CONTROL_NODES" -gt 1 ]; then
			echo "NONHA can only have one control node."
			display_help
		fi
	fi
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

##  ______________________________________
## |              DEPLOYMENT             |
## |_____________________________________|

if [ "$IS_DESTROY" -eq 0 ]; then
	create_python_venv

	if [ "$IS_UNINSTALL" -eq 0 ]; then
		deploy_vms
	fi

	activate_python_venv
	check_ssh_connection

	if [ "$IS_UNINSTALL" -eq 0 ]; then
		ansible-playbook k3s-cluster/playbook.yml -i k3s-cluster/inventory/hosts.yml
	else
		ansible-playbook k3s-cluster/playbook.yml -i k3s-cluster/inventory/hosts.yml -e "uninstall_k3s=true"
	fi
else
	destroy_vms
fi
