create_ansible_vars_file() {
	: "${K3S_VER:?K3S_VER is required}"
	: "${K3S_DATASTORE:?K3S_DATASTORE is required}"

	: "${MAIN_CONTROL_KUBEPORT:?MAIN_CONTROL_KUBEPORT is required}"
	: "${CONTROL_LB_VIRTUAL_IP:?CONTROL_LB_VIRTUAL_IP is required}"

	: "${METALLB_VER:?METALLB_VER is required}"
	: "${METALLB_IP_RANGE:?METALLB_IP_RANGE is required}"

	: "${RANCHER_VER:?RANCHER_VER is required}"
	: "${CERT_MANAGER_VER:?CERT_MANAGER_VER is required}"
	: "${RANCHER_N_REPLICAS:?RANCHER_N_REPLICAS is required}"
	: "${RANCHER_FQDN:?RANCHER_FQDN is required}"

	echo "k3s_ver: \"$K3S_VER\"" >"$ansible_var_file"
	echo "k3s_datastore: \"${K3S_DATASTORE}\"" >>"$ansible_var_file"
	echo "" >>"$ansible_var_file"

	echo "main_control_kubeport: \"$MAIN_CONTROL_KUBEPORT\"" >>"$ansible_var_file"
	echo "control_lb_virtual_ip: \"$CONTROL_LB_VIRTUAL_IP\"" >>"$ansible_var_file"
	echo "" >>"$ansible_var_file"

	echo "metallb_ver: \"$METALLB_VER\"" >>"$ansible_var_file"
	echo "metallb_ip_range: \"$METALLB_IP_RANGE\"" >>"$ansible_var_file"
	echo "" >>"$ansible_var_file"

	echo "rancher_ver: \"$RANCHER_VER\"" >>"$ansible_var_file"
	echo "cert_manager_ver: \"$CERT_MANAGER_VER\"" >>"$ansible_var_file"
	echo "rancher_n_replicas: \"$RANCHER_N_REPLICAS\"" >>"$ansible_var_file"
	echo "rancher_fqdn: \"$RANCHER_FQDN\"" >>"$ansible_var_file"
	echo "" >>"$ansible_var_file"

	echo "db_user: \"$DB_USER\"" >>"$ansible_var_file"
	echo "db_pass: \"$DB_PASS\"" >>"$ansible_var_file"
	echo "db_host: \"$DB_HOST\"" >>"$ansible_var_file"
	echo "db_port: \"$DB_PORT\"" >>"$ansible_var_file"
	echo "db_name: \"$DB_NAME\"" >>"$ansible_var_file"
}

##  ______________________________________
## |          Ansible Host File          |
## |_____________________________________|
create_ansible_hosts_file() {
	echo "[main_control]" >"${ansible_host_file}"
	echo "${CONTROL_NODE_NAME}01 ansible_host=${CONTROL_NODE_IPS[0]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
	echo "" >>"${ansible_host_file}"

	echo "[control_nodes]" >>"${ansible_host_file}"
	for ((n_node = 1; n_node < ${#CONTROL_NODE_IPS[@]}; n_node++)); do
		current_node_n=$(printf "%2s" "$((n_node + 1))" | tr ' ' '0')
		echo "${CONTROL_NODE_NAME}${current_node_n} ansible_host=${CONTROL_NODE_IPS[n_node]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
	done
	echo "" >>"${ansible_host_file}"

	echo "[worker_nodes]" >>"${ansible_host_file}"
	for ((n_node = 0; n_node < ${#WORKER_NODE_IPS[@]}; n_node++)); do
		current_node_n=$(printf "%2s" "$((n_node + 1))" | tr ' ' '0')
		echo "${WORKER_NODE_NAME}${current_node_n} ansible_host=${WORKER_NODE_IPS[n_node]%/*} ansible_user=${VM_USER} ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
	done
	echo "" >>"${ansible_host_file}"

	echo "[control_load_balancer]" >>"${ansible_host_file}"
	echo "lb-1 ansible_host=${CONTROL_NODE_LB_IPS[0]%/*} ansible_user=${VM_USER} keepalived_state=MASTER keepalived_priority=200 ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
	echo "lb-2 ansible_host=${CONTROL_NODE_LB_IPS[1]%/*} ansible_user=${VM_USER} keepalived_state=BACKUP keepalived_priority=100 ansible_ssh_common_args=\"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\"" >>"$ansible_host_file"
}
