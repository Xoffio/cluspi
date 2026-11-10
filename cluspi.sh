#!/bin/bash

# DEFAULT VARS
IS_DESTROY=0
IS_UNINSTALL=0
SKIP_VMS=0
CHECK_ONLY=0
DRY_RUN=0
K3S_VER="1.32.9+k3s1"
K3S_DATASTORE=""
MAIN_CONTROL_KUBEPORT="6443"
METALLB_VER="0.15.2"
HELM_VER="3.18.3"
CERT_MANAGER_VER="1.19.0"
RANCHER_VER="2.12.2"
INSTALL_RANCHER=false
RANCHER_N_REPLICAS=1

terraform_var_file="./terraform-proxmox/terraform.tfvars"
ansible_var_file="./k3s-cluster/group_vars/all.yml"
ansible_host_file="./k3s-cluster/inventory/hosts.yml"

source ./scripts/ansible_templates.sh
source ./scripts/ansible_fns.sh
source ./scripts/terraform_templates.sh
source ./scripts/terraform_fns.sh
source ./scripts/validation.sh
source ./scripts/preflight.sh

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
	echo "  -s, --skip-vms                     Skip Terraform. Use for upgrades and reconfiguration of existing nodes."
	echo "  -c, --check                        Run the read-only pre-flight checks and exit. Changes nothing."
	echo "  -n, --dry-run                      Run pre-flight, show the Terraform plan and Ansible --check --diff. Changes nothing."
	echo "  -h, --help                         Show this help message and exit."
	echo
	echo "Examples:"
	echo "  $(basename "$0")           # Run the script normally (e.g., deploy)"
	echo "  $(basename "$0") --datastore ETCD    # Deploy HA cluster with embedded etcd"
	echo "  $(basename "$0") --datastore EDB     # Deploy cluster with external database"
	echo "  $(basename "$0") --datastore EDB --skip-vms  # Upgrade or reconfigure without touching Terraform"
	echo "  $(basename "$0") --check             # Check cluster.yaml and the live environment"
	echo "  $(basename "$0") --datastore EDB --dry-run   # Show what a deploy would change"
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

source ./scripts/config.sh
load_cluster_config

IFS=',' read -ra CONTROL_NODE_TYPES <<<"$CONTROL_NODE_TYPES"
IFS=',' read -ra CONTROL_NODE_NAMES <<<"$CONTROL_NODE_NAMES"
IFS=',' read -ra WORKER_NODE_TYPES <<<"$WORKER_NODE_TYPES"
IFS=',' read -ra WORKER_NODE_NAMES <<<"$WORKER_NODE_NAMES"

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
		IS_UNINSTALL=1
		IS_DESTROY=1
		;;
	--skip-vms | -s)
		SKIP_VMS=1
		;;
	--check | -c)
		CHECK_ONLY=1
		;;
	--dry-run | -n)
		DRY_RUN=1
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

if [ "$SKIP_VMS" -eq 1 ] && [ "$IS_DESTROY" -eq 1 ]; then
	echo "--skip-vms can't be used with --destroy."
	display_help
fi

if [ "$DRY_RUN" -eq 1 ] && [ "$IS_UNINSTALL" -eq 1 ]; then
	echo "--dry-run only applies to deploys."
	display_help
fi

if [ "$IS_DESTROY" -eq 0 ] && [ "$IS_UNINSTALL" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ]; then
	if [ "$K3S_DATASTORE" != "ETCD" ] && [ "$K3S_DATASTORE" != "EDB" ] && [ "$K3S_DATASTORE" != "NONHA" ]; then
		echo "You need to set the option '--datastore'"
		display_help
	else
		if [ "$K3S_DATASTORE" == "ETCD" ] && [ "$CONTROL_NODE_COUNT" -lt 3 ]; then
			echo "ETCD needs a minimum of 3 control nodes."
			display_help
		fi

		if [ "$K3S_DATASTORE" == "NONHA" ] && [ "$CONTROL_NODE_COUNT" -gt 1 ]; then
			echo "NONHA can only have one control node."
			display_help
		fi
	fi
fi

is_control_node_types_valid
is_worker_node_types_valid
CONTROL_NODE_COUNT_TF=$(get_n_prox_nodes CONTROL_NODE_TYPES)
WORKER_NODE_COUNT_TF=$(get_n_prox_nodes WORKER_NODE_TYPES)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

##  ______________________________________
## |              Pre-flight            |
## |_____________________________________|
if [ "$IS_UNINSTALL" -eq 0 ] || [ "$CHECK_ONLY" -eq 1 ]; then
	run_preflight "$SKIP_VMS" "$K3S_DATASTORE"
	PREFLIGHT_STATUS=$?
	if [ "$CHECK_ONLY" -eq 1 ]; then
		exit "$PREFLIGHT_STATUS"
	fi
	if [ "$PREFLIGHT_STATUS" -ne 0 ]; then
		echo "Pre-flight checks failed. Fix the [FAIL] items above, then run again. Use --check to see them without deploying."
		exit 1
	fi
fi

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
if [ "$DRY_RUN" -eq 1 ] && [ "$SKIP_VMS" -eq 0 ]; then
	echo "== Terraform plan (no changes)"
	(cd terraform-proxmox && terraform init -input=false && terraform plan -input=false -lock=false) || exit 1
fi

create_python_venv

if [ "$DRY_RUN" -eq 1 ]; then
	activate_python_venv
	echo "== Ansible check mode (no changes; shell and command tasks are skipped)"
	ansible-playbook k3s-cluster/install.yml -i k3s-cluster/inventory/hosts.yml --check --diff
	exit $?
fi

if [ "$IS_UNINSTALL" -eq 0 ]; then
	if [ "$SKIP_VMS" -eq 1 ]; then
		echo "Skipping Terraform (--skip-vms)."
	else
		deploy_vms
	fi
fi

activate_python_venv
if [ "$IS_UNINSTALL" -eq 0 ]; then
	check_ssh_connection
	ansible-playbook k3s-cluster/install.yml -i k3s-cluster/inventory/hosts.yml || exit 1
	# ansible-playbook k3s-cluster/playbook.yml --list-tasks
	# ansible-playbook k3s-cluster/playbook.yml -i k3s-cluster/inventory/hosts.yml -vv --step --start-at-task "dev_machine : Check if Helm is already installed" #2>&1 | tee "cluspi_$(date +%F_%H-%M-%S).log"
	# ansible-playbook k3s-cluster/playbook.yml -i k3s-cluster/inventory/hosts.yml --step #2>&1 | tee "cluspi_$(date +%F_%H-%M-%S).log"
else
	ansible-playbook k3s-cluster/uninstall.yml -i k3s-cluster/inventory/hosts.yml -e "uninstall_k3s=true" || exit 1
	# ansible-playbook k3s-cluster/uninstall.yml -i k3s-cluster/inventory/hosts.yml --step -vv --start-at-task "main_control : Include DB drop tasks" -e "uninstall_k3s=true"
fi

if [ "$IS_DESTROY" -eq 1 ]; then
	destroy_vms
fi
