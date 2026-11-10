# Known gaps

Open issues and planned work are tracked in [TODO.md](../TODO.md). These are the ones that affect day-to-day use.

- **`NONHA` is not implemented.** `./cluspi.sh -d NONHA` passes validation, but no Ansible role installs a control plane for it. Use `ETCD` or `EDB`.
- **The ETCD main control node is not upgraded in place.** `roles/main_control/tasks/install_with_etcd.yml` has `creates: /etc/systemd/system/k3s.service`, so it's skipped once the service exists, even if `k3s.version` changed. Upgrade that node by hand, or remove the `creates:` line.
- **The kubeconfig is overwritten on every run.** `roles/dev_machine` replaces `~/.kube/config` with the cluster's file, which removes other contexts you have.
- **No drain before worker upgrades.** Workloads may restart during a worker upgrade.
- **Rancher upgrades in one jump.** `roles/rancher` installs `addons.rancher.version` directly, so skipping minor versions skips the required steps. Follow [upgrade/rancher.md](upgrade/rancher.md).
- **Load balancers are always created by Terraform.** There's no option to use existing VMs, so a plan can try to create `cn-lb01` and `cn-lb02` again if their state is lost.
- **`EXT` nodes are never created by Terraform.** Prepare them by hand first.
- **Template name must match.** `proxmox.template` must match a template that exists in Proxmox. The Packer template's `vm_name` is `ubuntu-server-2404`, but `cluster.yaml.example` uses `ubuntu-cloud-2404`.
- **The `kubectl` version is pinned** to `v1.34.1` in `roles/dev_machine/tasks/main.yml`. Update it there when you move to a newer cluster.
- **Terraform state is local.** `terraform-proxmox/terraform.tfstate` is gitignored and lives on the machine that runs `cluspi.sh`. If it's lost, Terraform can't tell which `PROX` VMs already exist.
