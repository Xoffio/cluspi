deploy_vms() {
	cd ./terraform-proxmox/ || exit 1
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

	# TODO: Load balancers
}
