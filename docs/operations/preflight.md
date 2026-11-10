# Pre-flight checks and dry runs

Three flags let you look before you change anything:

| Flag | What it does | Changes anything? |
|---|---|---|
| `-c`, `--check` | Runs the pre-flight checks and exits. | No |
| `-n`, `--dry-run` | Runs the pre-flight checks, then the Terraform plan, then Ansible in check mode. | No, but it writes the generated files (`terraform.tfvars`, `group_vars/all.yml`, `inventory/hosts.yml`) |
| `-s`, `--skip-vms` | Skips Terraform. Ansible configures the existing nodes. | Only what Ansible changes |

A normal deploy also runs the pre-flight checks first. If any check fails, it stops before Terraform or Ansible runs.

## Check only

```bash
./cluspi.sh --check -d EDB
```

`-d EDB` is optional. Without it the database check is skipped. Exit status is 0 when there are no failures, even if there are warnings.

Example output:

```
Pre-flight checks (read-only)

Tools:
  [ok]   yq is installed
  ...
Nodes (SSH):
  [ok]   cn01 (192.168.8.101): SSH as loco works
  ...
Cluster:
  [ok]   cn01 is in the cluster at 192.168.8.101
  [ok]   VIP 192.168.8.147 answers on 6443
Proxmox:
  [ok]   Proxmox API answers and the token is accepted
  [ok]   template ubuntu-cloud-2404 exists
Terraform state:
  [ok]   cn01 is in the Terraform state
Database:
  [ok]   database rmnas.opt2:3306 is reachable

Result: 0 failure(s), 1 warning(s)
```

Each line is `[ok]`, `[warn]` or `[FAIL]`. Warnings don't stop a deploy. Failures do.

## What's checked

**Tools:** `yq`, `jq`, `nc`, `ssh`, `curl`, and `terraform` (unless `--skip-vms`). `kubectl` is optional.

**Nodes:** every control node, worker and load balancer in `cluster.yaml` must accept SSH as `user.vm_user` with your key. The check also compares the hostname with the name in `cluster.yaml`. A different hostname is a warning.

**Cluster:** if `~/.kube/config` exists and the API answers:
- each control and worker node must be in the cluster at the IP in `cluster.yaml`. An IP mismatch is a failure.
- a node that isn't in the cluster yet is a warning in a normal deploy, and a failure with `--skip-vms` (which can't create VMs).
- a cluster node that isn't in `cluster.yaml` is a warning.

**VIP:** `k3s.vip` should answer on port 6443. With `--skip-vms`, a silent VIP is a failure.

**Proxmox:** with the token from `.env`:
- the API answers and accepts the token,
- every `PROX` node's target and the load balancer targets exist as Proxmox nodes,
- `proxmox.storage` exists,
- `proxmox.template` exists as a template.

**Terraform state:**
- a `PROX` node or load balancer that isn't in `terraform.tfstate` is a warning, because Terraform would try to create it.
- a VM in the state that isn't a `PROX` node or load balancer in `cluster.yaml` is a failure. Terraform would destroy it, for example after you change a node from `PROX` to `EXT`.

**Database (with `-d EDB`):** the host and port must be reachable, and the database must exist. If the `mysql` client is installed, the login is also tested. The password is passed through `MYSQL_PWD`, not on the command line.

## Dry run

```bash
./cluspi.sh --dry-run -d EDB
```

This runs the pre-flight checks, then `terraform init` and `terraform plan` (no apply), then Ansible in check mode (`--check --diff`). Check mode skips `shell` and `command` tasks, so it's a partial preview. Expect `Plan: 0 to add, 0 to change, 0 to destroy` when nothing needs changing.

The dry run needs the Python venv. On Debian or Ubuntu, install it with `sudo apt install python3.12-venv` (the version number may differ).

## Skip Terraform

```bash
./cluspi.sh -d EDB --skip-vms
```

Use this for upgrades and reconfiguration when the VMs are already correct. Pre-flight then requires:
- every node in `cluster.yaml` to be reachable and in the cluster,
- the cluster API and VIP to answer.

It can't be used with `--destroy`.

## Recommended order

1. `./cluspi.sh --check -d EDB`: fix any `[FAIL]` lines.
2. `./cluspi.sh --dry-run -d EDB`: read the Terraform plan and the Ansible preview.
3. `./cluspi.sh -d EDB` for a deploy, or `./cluspi.sh -d EDB --skip-vms` for an upgrade.
