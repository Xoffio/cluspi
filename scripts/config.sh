#!/bin/bash
# Loads cluster.yaml (non-secret settings) into the variables used by cluspi.sh.
# Requires yq (https://github.com/mikefarah/yq) v4.

CLUSTER_CONFIG="${CLUSTER_CONFIG:-./cluster.yaml}"

require_yq() {
	if ! command -v yq >/dev/null 2>&1; then
		echo "yq is required to read $CLUSTER_CONFIG. Install mikefarah yq v4: https://github.com/mikefarah/yq"
		exit 1
	fi
}

cfg() {
	yq -r "$1 // \"\"" "$CLUSTER_CONFIG"
}

validate_cluster_config() {
	local errors=0

	local bad_types
	bad_types=$(yq -r '[.control_nodes[], .worker_nodes[]] | map(select(.type != "PROX" and .type != "EXT")) | length' "$CLUSTER_CONFIG")
	if [ "$bad_types" != "0" ]; then
		echo "cluster.yaml: every node needs type PROX or EXT."
		errors=1
	fi

	local missing_target
	missing_target=$(yq -r '[.control_nodes[], .worker_nodes[]] | map(select(.type == "PROX" and (.target == null or .target == ""))) | length' "$CLUSTER_CONFIG")
	if [ "$missing_target" != "0" ]; then
		echo "cluster.yaml: PROX nodes need a target Proxmox node."
		errors=1
	fi

	local missing_ip
	missing_ip=$(yq -r '[.control_nodes[], .worker_nodes[], .load_balancers.nodes[]] | map(select(.ip == null or .ip == "")) | length' "$CLUSTER_CONFIG")
	if [ "$missing_ip" != "0" ]; then
		echo "cluster.yaml: every node needs an ip."
		errors=1
	fi

	local dup_names
	dup_names=$(yq -r '[.control_nodes[].name, .worker_nodes[].name] | length - (unique | length)' "$CLUSTER_CONFIG")
	if [ "$dup_names" != "0" ]; then
		echo "cluster.yaml: node names must be unique."
		errors=1
	fi

	local lb_count
	lb_count=$(yq -r '.load_balancers.nodes | length' "$CLUSTER_CONFIG")
	if [ "$lb_count" != "2" ]; then
		echo "cluster.yaml: load_balancers.nodes must have exactly 2 entries."
		errors=1
	fi

	if [ "$errors" -ne 0 ]; then
		exit 1
	fi
}

prox_sizes() {
	# $1 = node list (control_nodes|worker_nodes), $2 = field (cores|ram|disk),
	# $3 = role default from resources (may be empty), $4 = built-in default
	local key="$1" field="$2" role_default="$3" builtin="$4"
	ROLE_DEFAULT="${role_default:-$builtin}" yq -r \
		"[.$key[] | select(.type == \"PROX\") | (.$field // strenv(ROLE_DEFAULT))] | join(\",\")" "$CLUSTER_CONFIG"
}

load_cluster_config() {
	require_yq

	if [ ! -f "$CLUSTER_CONFIG" ]; then
		echo "$CLUSTER_CONFIG not found. Run ./scripts/init_cluster.sh or copy cluster.yaml.example to cluster.yaml."
		exit 1
	fi

	validate_cluster_config

	export PM_API_URL
	PM_API_URL=$(cfg '.proxmox.api_url')
	export TEMPLATE_NAME
	TEMPLATE_NAME=$(cfg '.proxmox.template')
	export STORAGE_NAME
	STORAGE_NAME=$(cfg '.proxmox.storage')
	export GATEWAY_IP
	GATEWAY_IP=$(cfg '.proxmox.gateway')
	export DNS_IP
	DNS_IP=$(cfg '.proxmox.dns')
	export VM_USER
	VM_USER=$(cfg '.user.vm_user')
	export GITHUB_USER
	GITHUB_USER=$(cfg '.user.github_user')

	export CONTROL_NODE_COUNT
	CONTROL_NODE_COUNT=$(yq -r '.control_nodes | length' "$CLUSTER_CONFIG")
	export CONTROL_NODE_NAMES
	CONTROL_NODE_NAMES=$(yq -r '[.control_nodes[].name] | join(",")' "$CLUSTER_CONFIG")
	export CONTROL_NODE_TYPES
	CONTROL_NODE_TYPES=$(yq -r '[.control_nodes[].type] | join(",")' "$CLUSTER_CONFIG")
	export CONTROL_NODE_IPS
	CONTROL_NODE_IPS=$(yq -r '[.control_nodes[].ip] | join(",")' "$CLUSTER_CONFIG")
	export CONTROL_NODE_PROX_TARGET_NODE
	CONTROL_NODE_PROX_TARGET_NODE=$(yq -r '[.control_nodes[] | (.target // "-")] | join(",")' "$CLUSTER_CONFIG")

	export WORKER_NODE_COUNT
	WORKER_NODE_COUNT=$(yq -r '.worker_nodes | length' "$CLUSTER_CONFIG")
	export WORKER_NODE_NAMES
	WORKER_NODE_NAMES=$(yq -r '[.worker_nodes[].name] | join(",")' "$CLUSTER_CONFIG")
	export WORKER_NODE_TYPES
	WORKER_NODE_TYPES=$(yq -r '[.worker_nodes[].type] | join(",")' "$CLUSTER_CONFIG")
	export WORKER_NODE_IPS
	WORKER_NODE_IPS=$(yq -r '[.worker_nodes[].ip] | join(",")' "$CLUSTER_CONFIG")
	export WORKER_NODE_PROX_TARGET_NODE
	WORKER_NODE_PROX_TARGET_NODE=$(yq -r '[.worker_nodes[] | (.target // "-")] | join(",")' "$CLUSTER_CONFIG")

	export CONTROL_NODE_LB_NAME
	CONTROL_NODE_LB_NAME=$(cfg '.load_balancers.name')
	export CONTROL_NODE_LB_IPS
	CONTROL_NODE_LB_IPS=$(yq -r '[.load_balancers.nodes[].ip] | join(",")' "$CLUSTER_CONFIG")
	export CONTROL_NODE_LB_PROX_TARGET_NODE
	CONTROL_NODE_LB_PROX_TARGET_NODE=$(yq -r '[.load_balancers.nodes[] | (.target // "-")] | join(",")' "$CLUSTER_CONFIG")

	export CONTROL_PROX_CORES
	CONTROL_PROX_CORES=$(prox_sizes control_nodes cores "$(cfg '.resources.control.cores')" 2)
	export CONTROL_PROX_RAM
	CONTROL_PROX_RAM=$(prox_sizes control_nodes ram "$(cfg '.resources.control.ram')" 2048)
	export CONTROL_PROX_DISK
	CONTROL_PROX_DISK=$(prox_sizes control_nodes disk "$(cfg '.resources.control.disk')" 32)
	export WORKER_PROX_CORES
	WORKER_PROX_CORES=$(prox_sizes worker_nodes cores "$(cfg '.resources.worker.cores')" 1)
	export WORKER_PROX_RAM
	WORKER_PROX_RAM=$(prox_sizes worker_nodes ram "$(cfg '.resources.worker.ram')" 1024)
	export WORKER_PROX_DISK
	WORKER_PROX_DISK=$(prox_sizes worker_nodes disk "$(cfg '.resources.worker.disk')" 32)

	export K3S_VER
	K3S_VER=$(cfg '.k3s.version')
	export CONTROL_LB_VIRTUAL_IP
	CONTROL_LB_VIRTUAL_IP=$(cfg '.k3s.vip')

	export METALLB_VER
	METALLB_VER=$(cfg '.metallb.version')
	export METALLB_IP_RANGE
	METALLB_IP_RANGE=$(cfg '.metallb.ip_range')

	export HELM_VER
	HELM_VER=$(cfg '.addons.helm_version')
	export CERT_MANAGER_VER
	CERT_MANAGER_VER=$(cfg '.addons.cert_manager_version')
	export INSTALL_RANCHER
	INSTALL_RANCHER=$(yq -r '.addons.rancher.install' "$CLUSTER_CONFIG")
	export RANCHER_VER
	RANCHER_VER=$(cfg '.addons.rancher.version')
	export RANCHER_N_REPLICAS
	RANCHER_N_REPLICAS=$(cfg '.addons.rancher.replicas')
	export RANCHER_FQDN
	RANCHER_FQDN=$(cfg '.addons.rancher.fqdn')

	export DB_HOST
	DB_HOST=$(cfg '.database.host')
	export DB_PORT
	DB_PORT=$(cfg '.database.port')
	export DB_NAME
	DB_NAME=$(cfg '.database.name')
	export DB_USER
	DB_USER=$(cfg '.database.user')
}
