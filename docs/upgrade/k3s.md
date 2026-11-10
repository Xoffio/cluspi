# Upgrade k3s

Before you start, back up `terraform-proxmox/terraform.tfstate` and the database (if you use `EDB`).

1. Read the [k3s release notes](https://github.com/k3s-io/k3s/releases) and the [version skew policy](https://docs.k3s.io/upgrades). Upgrade **one minor version at a time**, e.g. `1.32.x` → `1.33.x` → `1.34.x`.
2. Change `k3s.version` in `cluster.yaml`:

   ```yaml
   k3s:
     version: "1.33.5+k3s1"
   ```

3. Check the cluster, then run the upgrade. Use `--skip-vms` so Terraform doesn't run:

   ```bash
   ./cluspi.sh --check -d EDB --skip-vms
   ./cluspi.sh -d EDB --skip-vms
   ```

4. Check the result. Every node should show the new version:

   ```bash
   kubectl get nodes
   ```

## What happens during the run

Ansible upgrades nodes in the same order as the install: load balancers, main control, other control nodes, then workers. The load balancer, control and worker plays run one node at a time (`serial: 1`).

Each node's install task only runs when `k3s --version` doesn't match `k3s.version`, so nodes that are already upgraded are skipped.

Nodes are not drained yet, so workloads on a worker may restart during its upgrade. See [TODO.md](../../TODO.md).

## Rancher

If Rancher is installed, check its compatibility with the new k3s version before you upgrade. See [rancher.md](rancher.md).
