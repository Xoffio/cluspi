# Install

Make sure the [prerequisites](prerequisites.md) are met and [`cluster.yaml` and `.env`](configuration.md) are filled in.

## Choose a datastore

Pass the datastore with `-d`. It's required for every deploy.

| Option | What it deploys | Requirements |
|---|---|---|
| `-d ETCD` | HA cluster using embedded etcd | At least 3 control nodes. Slow disks can cause problems. |
| `-d EDB` | Cluster using an external MySQL-compatible database | Database created and reachable. HA needs at least 2 control nodes. |
| `-d NONHA` | Single control node with embedded SQLite | **Not implemented yet.** See [known-gaps.md](known-gaps.md). |

## Check first

Before a first deploy, run the read-only checks and a dry run. See [operations/preflight.md](operations/preflight.md).

```bash
./cluspi.sh --check -d EDB
./cluspi.sh --dry-run -d EDB
```

## Run the deploy

From the repository root:

```bash
./cluspi.sh -d EDB
```

The script does this, in order:

1. Runs the pre-flight checks and stops on any failure.
2. Validates `cluster.yaml` (node types, names, IPs, load balancer count) and checks the datastore rules.
2. Generates `terraform-proxmox/terraform.tfvars`, `k3s-cluster/group_vars/all.yml` and `k3s-cluster/inventory/hosts.yml`.
3. Creates the Python venv in `./dev` and installs `requirements.txt`.
4. Runs `terraform init`, `plan` and `apply` with `-parallelism 1`. Terraform asks you to confirm the apply. Read the plan first.
5. Waits until SSH answers on every VM.
6. Runs `k3s-cluster/install.yml`, which configures nodes in this order: load balancers, main control, other control nodes, workers, MetalLB, dev machine (kubeconfig, kubectl, helm), cert-manager, and Rancher if `addons.rancher.install` is `true`.

A full deploy takes a while. Terraform adds about 30 seconds per VM, and the k3s install waits on each node.

## Verify

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

The kubeconfig is written to `~/.kube/config`, with the server set to `https://<k3s.vip>:6443`. If you already had a config there, Ansible saves a backup next to it. See [known-gaps.md](known-gaps.md) for the overwrite issue.

Make sure `~/.local/bin` is on your `PATH`, because that's where `kubectl` and `helm` are installed.
