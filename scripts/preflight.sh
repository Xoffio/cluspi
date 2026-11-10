#!/bin/bash
# Read-only checks run before a deploy (see docs/operations/preflight.md).
# Uses the variables loaded by cluspi.sh from .env and cluster.yaml.
# Nothing here changes Proxmox, the cluster or the VMs.

PF_SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
PF_FAILS=0
PF_WARNS=0

pf_ok() { echo "  [ok]   $*"; }
pf_warn() {
	echo "  [warn] $*"
	PF_WARNS=$((PF_WARNS + 1))
}
pf_fail() {
	echo "  [FAIL] $*"
	PF_FAILS=$((PF_FAILS + 1))
}

# Joins its arguments with commas. Works on the comma strings and on the
# arrays that cluspi.sh builds from them.
pf_join() {
	local IFS=,
	printf '%s' "$*"
}

# Prints one line per node: "<role> <name> <ip without CIDR> <type> <target or ->"
pf_nodes() {
	local -a names ips types targets
	local i

	IFS=',' read -ra names <<<"$(pf_join "${CONTROL_NODE_NAMES[@]}")"
	IFS=',' read -ra ips <<<"$(pf_join "${CONTROL_NODE_IPS[@]}")"
	IFS=',' read -ra types <<<"$(pf_join "${CONTROL_NODE_TYPES[@]}")"
	IFS=',' read -ra targets <<<"$(pf_join "${CONTROL_NODE_PROX_TARGET_NODE[@]}")"
	for i in "${!names[@]}"; do
		printf 'control %s %s %s %s\n' "${names[$i]}" "${ips[$i]%/*}" "${types[$i]}" "${targets[$i]:--}"
	done

	IFS=',' read -ra names <<<"$(pf_join "${WORKER_NODE_NAMES[@]}")"
	IFS=',' read -ra ips <<<"$(pf_join "${WORKER_NODE_IPS[@]}")"
	IFS=',' read -ra types <<<"$(pf_join "${WORKER_NODE_TYPES[@]}")"
	IFS=',' read -ra targets <<<"$(pf_join "${WORKER_NODE_PROX_TARGET_NODE[@]}")"
	for i in "${!names[@]}"; do
		printf 'worker %s %s %s %s\n' "${names[$i]}" "${ips[$i]%/*}" "${types[$i]}" "${targets[$i]:--}"
	done

	IFS=',' read -ra ips <<<"$(pf_join "${CONTROL_NODE_LB_IPS[@]}")"
	IFS=',' read -ra targets <<<"$(pf_join "${CONTROL_NODE_LB_PROX_TARGET_NODE[@]}")"
	for i in "${!ips[@]}"; do
		printf 'lb %s%02d %s PROX %s\n' "$CONTROL_NODE_LB_NAME" "$((i + 1))" "${ips[$i]%/*}" "${targets[$i]:--}"
	done
}

pf_tools() {
	local tool
	for tool in yq jq nc ssh curl; do
		if command -v "$tool" >/dev/null 2>&1; then
			pf_ok "$tool is installed"
		else
			pf_fail "$tool is not installed"
		fi
	done

	if [ "$1" = 1 ]; then
		if command -v terraform >/dev/null 2>&1; then
			pf_ok "terraform is installed"
		else
			pf_fail "terraform is not installed (needed unless --skip-vms)"
		fi
	fi

	if command -v kubectl >/dev/null 2>&1; then
		pf_ok "kubectl is installed"
	else
		pf_warn "kubectl is not installed; the cluster state can't be compared"
	fi
}

pf_nodes_reachable() {
	local role name ip type target host
	while read -r role name ip type target; do
		[ -z "$name" ] && continue
		if ! nc -z -w3 "$ip" 22 >/dev/null 2>&1; then
			pf_fail "$name ($ip): SSH port is closed or the host is unreachable"
			continue
		fi
		host=$(timeout 15 ssh -n "${PF_SSH_OPTS[@]}" "$VM_USER@$ip" hostname 2>/dev/null)
		if [ -z "$host" ]; then
			pf_fail "$name ($ip): SSH as $VM_USER failed (check vm_user and your key)"
			continue
		fi
		if [ "$host" = "$name" ]; then
			pf_ok "$name ($ip): SSH as $VM_USER works"
		else
			pf_warn "$name ($ip): SSH works, but the hostname is '$host' (cluster.yaml says '$name')"
		fi
	done < <(pf_nodes)
}

pf_cluster() {
	local skip="$1"
	local kubeconfig="$HOME/.kube/config"
	local json live role name ip type target found lname lip

	if ! command -v kubectl >/dev/null 2>&1 || [ ! -f "$kubeconfig" ]; then
		pf_warn "No kubeconfig at $kubeconfig, so the cluster state isn't compared (normal for a first install)"
		return
	fi

	if ! json=$(timeout 20 kubectl --kubeconfig "$kubeconfig" get nodes -o json 2>/dev/null); then
		if [ "$skip" = 1 ]; then
			pf_fail "--skip-vms needs a running cluster, but the API at $CONTROL_LB_VIRTUAL_IP:6443 did not answer"
		else
			pf_warn "The API at $CONTROL_LB_VIRTUAL_IP:6443 did not answer, so the cluster state isn't compared"
		fi
		return
	fi

	live=$(jq -r '.items[] | .metadata.name + " " + ([.status.addresses[] | select(.type == "InternalIP") | .address][0] // "-")' <<<"$json")

	while read -r role name ip type target; do
		[ -z "$name" ] && continue
		[ "$role" = lb ] && continue
		found=$(awk -v n="$name" '$1 == n { print $2 }' <<<"$live")
		if [ -z "$found" ]; then
			if [ "$skip" = 1 ]; then
				pf_fail "$name is in cluster.yaml but not in the cluster. --skip-vms can't create VMs, so run without it"
			else
				pf_warn "$name is not in the cluster yet and will join on deploy"
			fi
		elif [ "$found" != "$ip" ]; then
			pf_fail "$name is in the cluster at $found, but cluster.yaml says $ip"
		else
			pf_ok "$name is in the cluster at $ip"
		fi
	done < <(pf_nodes | grep -v '^lb ')

	while read -r lname lip; do
		[ -z "$lname" ] && continue
		if ! pf_nodes | awk '{ print $2 }' | grep -qx "$lname"; then
			pf_warn "cluster node $lname ($lip) is not in cluster.yaml"
		fi
	done <<<"$live"
}

pf_vip() {
	local skip="$1"
	if nc -z -w3 "$CONTROL_LB_VIRTUAL_IP" 6443 >/dev/null 2>&1; then
		pf_ok "VIP $CONTROL_LB_VIRTUAL_IP answers on 6443"
	elif [ "$skip" = 1 ]; then
		pf_fail "VIP $CONTROL_LB_VIRTUAL_IP does not answer on 6443, so the load balancers may be down"
	else
		pf_warn "VIP $CONTROL_LB_VIRTUAL_IP does not answer on 6443 (expected on a first install)"
	fi
}

pf_pm_get() {
	printf 'header = "Authorization: PVEAPIToken=%s=%s"\n' "$PM_API_TOKEN_ID" "$PM_API_TOKEN_SECRET" |
		curl -sk -m 15 -K - "$PM_API_URL$1"
}

pf_proxmox() {
	local needed="$1"
	local status nodes storage template_count target role name ip type target_node

	if [ -z "$PM_API_TOKEN_ID" ] || [ -z "$PM_API_TOKEN_SECRET" ]; then
		if [ "$needed" = 1 ]; then
			pf_fail "PM_API_TOKEN_ID or PM_API_TOKEN_SECRET is not set in .env"
		else
			pf_warn "PM_API_TOKEN_ID or PM_API_TOKEN_SECRET is not set in .env"
		fi
		return
	fi

	status=$(printf 'header = "Authorization: PVEAPIToken=%s=%s"\n' "$PM_API_TOKEN_ID" "$PM_API_TOKEN_SECRET" |
		curl -sk -m 15 -o /dev/null -w '%{http_code}' -K - "$PM_API_URL/version" 2>/dev/null)
	case "$status" in
	200) pf_ok "Proxmox API answers and the token is accepted" ;;
	401 | 403)
		[ "$needed" = 1 ] && pf_fail "Proxmox rejected the token (HTTP $status). Check PM_API_TOKEN_ID and PM_API_TOKEN_SECRET in .env" ||
			pf_warn "Proxmox rejected the token (HTTP $status)"
		return
		;;
	*)
		[ "$needed" = 1 ] && pf_fail "Proxmox API at $PM_API_URL is not reachable (HTTP ${status:-none})" ||
			pf_warn "Proxmox API at $PM_API_URL is not reachable (HTTP ${status:-none})"
		return
		;;
	esac

	nodes=$(pf_pm_get /nodes | jq -r '.data[].node' 2>/dev/null)
	while read -r role name ip type target_node; do
		[ -z "$name" ] && continue
		[ "$type" != PROX ] && [ "$role" != lb ] && continue
		if grep -qx "$target_node" <<<"$nodes"; then
			pf_ok "Proxmox node $target_node exists (for $name)"
		else
			pf_fail "Proxmox node '$target_node' (for $name) does not exist. Available: $(echo $nodes)"
		fi
	done < <(pf_nodes)

	storage=$(pf_pm_get /storage | jq -r '.data[].storage' 2>/dev/null)
	if grep -qx "$STORAGE_NAME" <<<"$storage"; then
		pf_ok "storage $STORAGE_NAME exists"
	else
		pf_fail "storage '$STORAGE_NAME' not found in Proxmox"
	fi

	template_count=$(pf_pm_get '/cluster/resources?type=vm' |
		jq --arg t "$TEMPLATE_NAME" '[.data[] | select(.template == 1 and .name == $t)] | length' 2>/dev/null)
	if [ "${template_count:-0}" -gt 0 ]; then
		pf_ok "template $TEMPLATE_NAME exists"
	else
		pf_fail "template '$TEMPLATE_NAME' not found. Check proxmox.template in cluster.yaml"
	fi
}

pf_terraform_state() {
	local skip="$1"
	local state="terraform-proxmox/terraform.tfstate"
	local expected tracked name

	expected=$(pf_nodes | awk '$4 == "PROX" || $1 == "lb" { print $2 }' | sort -u)

	if [ ! -f "$state" ]; then
		if [ -n "$expected" ] && [ "$skip" = 0 ]; then
			pf_warn "No $state. Terraform would try to create these VMs, and creating ones that already exist will fail or duplicate them: $(echo $expected)"
		else
			pf_ok "No $state (not needed for this run)"
		fi
		return
	fi

	tracked=$(jq -r '.resources[] | select(.type == "proxmox_vm_qemu") | .instances[].attributes.name' "$state" 2>/dev/null | sort -u)

	for name in $expected; do
		if grep -qx "$name" <<<"$tracked"; then
			pf_ok "$name is in the Terraform state"
		elif [ "$skip" = 0 ]; then
			pf_warn "$name is not in the Terraform state, so Terraform will try to create it"
		fi
	done

	for name in $tracked; do
		if ! grep -qx "$name" <<<"$expected"; then
			pf_fail "the Terraform state tracks $name, which is not a PROX node or load balancer in cluster.yaml. Terraform would destroy it"
		fi
	done
}

pf_database() {
	local datastore="$1"
	[ "$datastore" = EDB ] || return

	if ! nc -z -w3 "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; then
		pf_fail "database $DB_HOST:$DB_PORT is not reachable"
		return
	fi
	pf_ok "database $DB_HOST:$DB_PORT is reachable"

	if ! command -v mysql >/dev/null 2>&1; then
		pf_warn "the mysql client is not installed, so the database login isn't tested"
		return
	fi

	local found
	found=$(MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -N -B \
		-e "SHOW DATABASES LIKE '$DB_NAME'" 2>/dev/null)
	if [ "$?" -ne 0 ] && [ -z "$found" ]; then
		pf_fail "database login as $DB_USER failed (check DB_PASS in .env)"
	elif [ -z "$found" ]; then
		pf_fail "database $DB_NAME does not exist. Create it before the k3s install"
	else
		pf_ok "database $DB_NAME exists and the login works"
	fi
}

# run_preflight <skip_vms 0|1> <datastore>
run_preflight() {
	local skip="$1" datastore="$2"

	PF_FAILS=0
	PF_WARNS=0
	local needs_terraform=1
	[ "$skip" = 1 ] && needs_terraform=0

	echo "Pre-flight checks (read-only)"
	echo
	echo "Tools:"
	pf_tools "$needs_terraform"
	echo
	echo "Nodes (SSH):"
	pf_nodes_reachable
	echo
	echo "Cluster:"
	pf_cluster "$skip"
	pf_vip "$skip"
	echo
	echo "Proxmox:"
	pf_proxmox "$needs_terraform"
	echo
	echo "Terraform state:"
	pf_terraform_state "$skip"
	echo
	echo "Database:"
	if [ -n "$datastore" ]; then
		pf_database "$datastore"
	else
		pf_warn "no datastore given (-d), so the database check was skipped"
	fi
	echo
	echo "Result: $PF_FAILS failure(s), $PF_WARNS warning(s)"

	[ "$PF_FAILS" -eq 0 ]
}
