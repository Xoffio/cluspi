# Cluspi

Cluspi builds a k3s Kubernetes cluster on Proxmox. One script, `cluspi.sh`, runs Terraform (VMs), Ansible (k3s and add-ons), and gives you a working cluster.

Full documentation is in [`docs/`](docs/index.md).

## Install

1. Install the prerequisites: [docs/prerequisites.md](docs/prerequisites.md).
2. Create your config. The wizard asks a question for each value and writes `cluster.yaml` and `.env`:

   ```bash
   ./scripts/init_cluster.sh
   ```

3. Check the environment, then deploy with an external MySQL database (`EDB`):

   ```bash
   ./cluspi.sh --check -d EDB
   ./cluspi.sh -d EDB
   ```

4. Check the cluster:

   ```bash
   kubectl get nodes -o wide
   ```

Details: [docs/install.md](docs/install.md) · settings: [docs/configuration.md](docs/configuration.md)

## Upgrade

1. Back up `terraform-proxmox/terraform.tfstate` and your database.
2. Change the version in `cluster.yaml`.
3. Re-run with `--skip-vms` for version changes (Terraform isn't needed), after a check:

   ```bash
   ./cluspi.sh --check -d EDB --skip-vms
   ./cluspi.sh -d EDB --skip-vms
   ```

   Changes to VM sizes or node lists need the full deploy (without `--skip-vms`). Run `./cluspi.sh --dry-run -d EDB` first.

- **k3s:** [docs/upgrade/k3s.md](docs/upgrade/k3s.md)
- **MetalLB, cert-manager, Helm:** [docs/upgrade/add-ons.md](docs/upgrade/add-ons.md)
- **Rancher:** [docs/upgrade/rancher.md](docs/upgrade/rancher.md). Rancher must go one minor version at a time, and the k3s version has to be in its compatibility range.

## Uninstall

```bash
./cluspi.sh -u   # remove k3s and add-ons, keep the VMs
./cluspi.sh -x   # remove k3s and destroy the VMs
```

See [docs/uninstall.md](docs/uninstall.md).

## Known issues

See [docs/known-gaps.md](docs/known-gaps.md) and [TODO.md](TODO.md).
