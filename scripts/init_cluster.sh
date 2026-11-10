#!/bin/bash
# Interactive setup: writes cluster.yaml (topology and settings) and .env (secrets).
# Run from the repository root: ./scripts/init_cluster.sh

set -e

if ! command -v yq >/dev/null 2>&1; then
	echo "yq is required (https://github.com/mikefarah/yq, v4)."
	exit 1
fi

ask() {
	local prompt="$1" default="$2" answer
	read -rp "$prompt [$default]: " answer
	printf '%s' "${answer:-$default}"
}

ask_secret() {
	local prompt="$1" answer
	read -rsp "$prompt: " answer
	echo >&2
	printf '%s' "$answer"
}

upper() {
	printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

confirm_overwrite() {
	local file="$1"
	if [ -f "$file" ]; then
		local answer
		read -rp "$file already exists. Back it up and replace it? [y/N]: " answer
		[[ "$answer" =~ ^[Yy]$ ]] || { echo "Keeping $file. Exiting."; exit 1; }
		cp "$file" "$file.bak"
		chmod 600 "$file.bak" 2>/dev/null || true
		echo "Backed up to $file.bak"
	fi
}

ask_node_list() {
	# $1 = label (e.g. "control node"), $2 = default count, $3 = default name prefix
	local label="$1" default_count="$2" prefix="$3"
	local count i name type ip target
	count=$(ask "Number of $label" "$default_count")
	for ((i = 1; i <= count; i++)); do
		echo >&2
		echo "$label $i:" >&2
		name=$(ask "  Name" "$prefix$(printf '%02d' "$i")")
		type=$(upper "$(ask "  Type (PROX = Terraform creates it, EXT = already exists)" "PROX")")
		while [[ "$type" != "PROX" && "$type" != "EXT" ]]; do
			echo "  Type must be PROX or EXT." >&2
			type=$(upper "$(ask "  Type (PROX or EXT)" "PROX")")
		done
		ip=$(ask "  IP with CIDR, e.g. 192.168.1.101/24" "")
		target=""
		if [ "$type" = "PROX" ]; then
			target=$(ask "  Proxmox node to create it on" "prox01")
		fi
		printf '%s\t%s\t%s\t%s\n' "$name" "$type" "$ip" "$target"
	done
}

echo "cluspi setup"
echo "Press Enter to accept the value in brackets."
echo

echo "== Proxmox"
api_url=$(ask "Proxmox API URL" "https://prox01.lan:8006/api2/json")
template=$(ask "Template to clone (cloud-init Ubuntu)" "ubuntu-cloud-2404")
storage=$(ask "Storage for VM disks" "local")
gateway=$(ask "Gateway IP" "192.168.1.1")
dns=$(ask "DNS IP" "192.168.1.1")

echo
echo "== Access to the VMs"
vm_user=$(ask "Login user on the VMs (needs passwordless sudo)" "ubuntu")
github_user=$(ask "GitHub username (SSH keys are pulled from github.com/<name>.keys)" "")
while [ -z "$github_user" ]; do
	github_user=$(ask "GitHub username is required" "")
done

echo
echo "== VM sizing for PROX nodes (one size per role, applied to every PROX node of that role)"
control_cores=$(ask "Control node CPU cores" "2")
control_ram=$(ask "Control node RAM (MB)" "2048")
control_disk=$(ask "Control node disk (GB)" "32")
worker_cores=$(ask "Worker node CPU cores" "1")
worker_ram=$(ask "Worker node RAM (MB)" "1024")
worker_disk=$(ask "Worker node disk (GB)" "32")

echo
echo "== Control plane nodes (3 for ETCD, 1-3 for EDB)"
control_rows=$(ask_node_list "control node" 3 "cn")

echo
echo "== Worker nodes"
worker_rows=$(ask_node_list "worker node" 2 "wn")

echo
echo "== Load balancers (always two, created by Terraform)"
lb_name=$(ask "Load balancer name prefix" "cn-lb")
lb1_ip=$(ask "Load balancer 1 IP with CIDR" "")
lb1_target=$(ask "  Proxmox node for load balancer 1" "prox01")
lb2_ip=$(ask "Load balancer 2 IP with CIDR" "")
lb2_target=$(ask "  Proxmox node for load balancer 2" "prox01")

echo
echo "== Kubernetes"
k3s_version=$(ask "k3s version" "1.32.9+k3s1")
datastore=$(ask "Datastore (ETCD or EDB; the deploy flag -d is what is actually used)" "EDB")
vip=$(ask "Control-plane VIP (must be free on the LAN)" "")

echo
echo "== External database (only for EDB)"
db_host=$(ask "Database host" "")
db_port=$(ask "Database port" "3306")
db_name=$(ask "Database name" "k3s")
db_user=$(ask "Database user" "root")
db_pass=$(ask_secret "Database password (stored in .env)")

echo
echo "== Load balancer for services (MetalLB)"
metallb_version=$(ask "MetalLB version" "0.15.2")
metallb_range=$(ask "IP range for LoadBalancer services" "")

echo
echo "== Add-ons"
helm_version=$(ask "Helm version (used only if helm is missing)" "3.18.3")
cert_manager_version=$(ask "cert-manager version" "1.19.0")
rancher_install=$(ask "Install Rancher? (true/false)" "false")
rancher_version=$(ask "Rancher version" "2.12.2")
rancher_replicas=$(ask "Rancher replicas" "1")
rancher_fqdn=$(ask "Rancher hostname" "cluspi.lan")

echo
echo "== Proxmox API token (stored in .env)"
token_id=$(ask "Token ID" "terraform-prov@pve!terraform-token")
token_secret=$(ask_secret "Token secret")

confirm_overwrite cluster.yaml
{
	echo "proxmox:"
	echo "  api_url: \"$api_url\""
	echo "  template: \"$template\""
	echo "  storage: \"$storage\""
	echo "  gateway: \"$gateway\""
	echo "  dns: \"$dns\""
	echo
	echo "user:"
	echo "  vm_user: \"$vm_user\""
	echo "  github_user: \"$github_user\""
	echo
	echo "resources:"
	echo "  control:"
	echo "    cores: $control_cores"
	echo "    ram: $control_ram"
	echo "    disk: $control_disk"
	echo "  worker:"
	echo "    cores: $worker_cores"
	echo "    ram: $worker_ram"
	echo "    disk: $worker_disk"
	echo
	echo "control_nodes:"
	while IFS=$'\t' read -r name type ip target; do
		[ -z "$name" ] && continue
		echo "  - name: \"$name\""
		echo "    type: $type"
		echo "    ip: \"$ip\""
		[ -n "$target" ] && echo "    target: \"$target\""
	done <<<"$control_rows"
	echo
	echo "worker_nodes:"
	while IFS=$'\t' read -r name type ip target; do
		[ -z "$name" ] && continue
		echo "  - name: \"$name\""
		echo "    type: $type"
		echo "    ip: \"$ip\""
		[ -n "$target" ] && echo "    target: \"$target\""
	done <<<"$worker_rows"
	echo
	echo "load_balancers:"
	echo "  name: \"$lb_name\""
	echo "  nodes:"
	echo "    - ip: \"$lb1_ip\""
	echo "      target: \"$lb1_target\""
	echo "    - ip: \"$lb2_ip\""
	echo "      target: \"$lb2_target\""
	echo
	echo "k3s:"
	echo "  version: \"$k3s_version\""
	echo "  datastore: $datastore"
	echo "  vip: \"$vip\""
	echo
	echo "database:"
	echo "  host: \"$db_host\""
	echo "  port: $db_port"
	echo "  name: \"$db_name\""
	echo "  user: \"$db_user\""
	echo
	echo "metallb:"
	echo "  version: \"$metallb_version\""
	echo "  ip_range: \"$metallb_range\""
	echo
	echo "addons:"
	echo "  helm_version: \"$helm_version\""
	echo "  cert_manager_version: \"$cert_manager_version\""
	echo "  rancher:"
	echo "    install: $rancher_install"
	echo "    version: \"$rancher_version\""
	echo "    replicas: $rancher_replicas"
	echo "    fqdn: \"$rancher_fqdn\""
} >cluster.yaml
echo "Wrote cluster.yaml"

confirm_overwrite .env
umask 077
{
	echo "# Secrets only. Everything else is in cluster.yaml. Do not commit this file."
	echo "PM_API_TOKEN_ID=$token_id"
	echo "PM_API_TOKEN_SECRET=$token_secret"
	echo "DB_PASS=$db_pass"
} >.env
chmod 600 .env
echo "Wrote .env (permissions 600)"

echo
echo "Checking cluster.yaml..."
CLUSTER_CONFIG=./cluster.yaml
source ./scripts/config.sh
load_cluster_config
echo "cluster.yaml is valid. Review it, then run: ./cluspi.sh -d $datastore"
