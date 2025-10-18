deploy_vms() {
	cd ./terraform-proxmox/ || exit 1

	terraform validate
	if [ $? -ne 0 ]; then
		echo "Terraform validation failed."
		exit 1
	fi

	terraform init --upgrade &&
		terraform plan &&
		terraform apply -auto-approve -parallelism 1 || (echo "Terraform Failed" && exit 1)
}

destroy_vms() {
	cd ./terraform-proxmox/ || exit 1
	terraform init --upgrade &&
		terraform destroy
}

check_ssh_connection() {
	echo "[*] Making sure control nodes are ready to be setup..."
	for n in "${CONTROL_NODE_IPS[@]}"; do
		ip="${n%/*}"

		echo "    Waiting for SSH on $ip..."
		while ! nc -z -w2 "$ip" 22 2>/dev/null; do
			sleep 1
		done
		echo "      SSH is up in $ip"
	done

	echo ""
	echo "[*] Making sure worker nodes are ready to be setup..."
	for n in "${WORKER_NODE_IPS[@]}"; do
		ip="${n%/*}"

		echo "    Waiting for SSH on $ip..."
		while ! nc -z -w2 "$ip" 22 2>/dev/null; do
			sleep 1
		done
		echo "      SSH is up in $ip"
	done

	# TODO: Only do this if the cluster will be HA
	echo ""
	echo "[*] Making sure the load balancer nodes are ready to be setup..."
	for n in "${CONTROL_NODE_LB_IPS[@]}"; do
		ip="${n%/*}"

		echo "    Waiting for SSH on $ip..."
		while ! nc -z -w2 "$ip" 22 2>/dev/null; do
			sleep 1
		done
		echo "      SSH is up in $ip"
	done
}

get_n_prox_nodes() {
	local -n arr_ref=$1 # Create a nameref to the passed array name
	local counter

	counter=0
	for i in "${!arr_ref[@]}"; do
		if [[ "${arr_ref[$i]}" == "PROX" ]]; then
			((counter++))
		fi
	done

	echo "$counter"
}
