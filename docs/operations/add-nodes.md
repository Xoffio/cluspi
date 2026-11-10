# Add nodes

To add a worker, for example:

1. Add an entry to `worker_nodes` in `cluster.yaml`. Use `type: PROX` to have Terraform create it, or `type: EXT` if the VM already exists:

   ```yaml
   worker_nodes:
     - name: wn01
       type: EXT
       ip: 192.168.1.111/24
     - name: wn02
       type: EXT
       ip: 192.168.1.112/24
     - name: wn03
       type: PROX
       ip: 192.168.1.113/24
       target: prox01
   ```

   Add new entries at the end of the list. Terraform identifies `PROX` VMs by their position, so inserting or reordering entries changes which VM Terraform thinks it manages.

2. Check the plan: `cd terraform-proxmox && terraform plan`. A new `PROX` node should show as "to add", and existing VMs shouldn't be replaced.

3. Run the deploy:

   ```bash
   ./cluspi.sh -d EDB
   ```

Adding control nodes works the same way. For `ETCD`, keep an odd number of control nodes (3, 5, …).

Terraform needs `terraform-proxmox/terraform.tfstate` to know which `PROX` VMs already exist. Keep a backup of it.
