# Configuration

Cluspi uses two files:

| File | Contains | Committed? |
|---|---|---|
| `cluster.yaml` | Topology and settings: nodes, IPs, Proxmox targets, versions | No (gitignored). Use `cluster.yaml.example` as the template. |
| `.env` | Secrets only: the Proxmox token ID and secret, and the database password | No (gitignored). Use `.env_sample` as the template. |

## Create the files

The wizard asks a question for each value and writes both files:

```bash
./scripts/init_cluster.sh
```

It writes `cluster.yaml`, writes `.env` with permissions 600, and checks the result. Existing files are backed up to `.bak` first.

To fill them in by hand:

```bash
cp cluster.yaml.example cluster.yaml
cp .env_sample .env
```

The comments in `cluster.yaml.example` explain each field.

## `cluster.yaml` at a glance

```yaml
proxmox:        # API URL, template, storage, gateway, DNS
user:           # vm_user (login on the VMs), github_user (SSH keys)
resources:      # Default cores, ram (MB) and disk (GB) for PROX VMs
control_nodes:  # name, type (PROX|EXT), ip, target (PROX only), optional cores/ram/disk
worker_nodes:   # name, type (PROX|EXT), ip, target (PROX only), optional cores/ram/disk
load_balancers: # name prefix and exactly two nodes (ip, target)
k3s:            # version, datastore (documentation only), vip
database:       # host, port, name, user (password is in .env)
metallb:        # version, ip_range
addons:         # helm_version, cert_manager_version, rancher (install, version, replicas, fqdn)
```

## `PROX` and `EXT` nodes

- **`PROX`**: Terraform creates the VM on Proxmox from `proxmox.template`. It needs a `target`, the Proxmox node name such as `prox01`.
- **`EXT`**: the VM already exists. Terraform skips it, and Ansible configures it.

Terraform tracks `PROX` VMs by their position in the list. Don't reorder entries that already exist in `terraform-proxmox/terraform.tfstate`.

A `PROX` node can set its own `cores`, `ram` and `disk`. Anything it leaves out uses the role default under `resources`. Load balancers and `EXT` nodes don't use these values. See [operations/resize-vms.md](operations/resize-vms.md).

## What's in `.env`

```
PM_API_TOKEN_ID=terraform-prov@pve!terraform-token
PM_API_TOKEN_SECRET=...
DB_PASS=...
```

Keep this file private. It's read by `cluspi.sh` and never copied into the repository.

## Where the old `.env` variables went

Older versions kept everything in `.env`. These are now in `cluster.yaml`:

| Old `.env` variable | `cluster.yaml` field |
|---|---|
| `PM_API_URL` | `proxmox.api_url` |
| `TEMPLATE_NAME`, `STORAGE_NAME`, `GATEWAY_IP`, `DNS_IP` | `proxmox.template`, `proxmox.storage`, `proxmox.gateway`, `proxmox.dns` |
| `VM_USER`, `GITHUB_USER` | `user.vm_user`, `user.github_user` |
| `CONTROL_NODE_*`, `WORKER_NODE_*` | `control_nodes`, `worker_nodes` (name, type, ip, target) |
| `CONTROL_NODE_CORES`, `_RAM_SIZE`, `_DISK_SIZE` (and worker equivalents) | `resources.control`, `resources.worker`, or per node |
| `CONTROL_NODE_LB_*` | `load_balancers` |
| `K3S_VER`, `CONTROL_LB_VIRTUAL_IP` | `k3s.version`, `k3s.vip` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` | `database.host`, `database.port`, `database.name`, `database.user` |
| `METALLB_VER`, `METALLB_IP_RANGE` | `metallb.version`, `metallb.ip_range` |
| `HELM_VER`, `CERT_MANAGER_VER` | `addons.helm_version`, `addons.cert_manager_version` |
| `INSTALL_RANCHER`, `RANCHER_VER`, `RANCHER_N_REPLICAS`, `RANCHER_FQDN` | `addons.rancher.install`, `.version`, `.replicas`, `.fqdn` |

`K3S_DATASTORE` is set by the `-d` flag at deploy time, not by a config file. If a legacy `.env` still contains a non-secret variable, `cluster.yaml` takes precedence.
