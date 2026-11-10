# Architecture

## Components

1. **Terraform** (`terraform-proxmox/`) creates the Proxmox VMs: control nodes, workers and the two HAProxy/Keepalived load balancers.
2. **Ansible** (`k3s-cluster/`) configures the VMs, installs k3s, then installs MetalLB, cert-manager and optionally Rancher.
3. **Packer** (`packer/proxmox/`, optional) builds the Ubuntu cloud-init template that Terraform clones.

`cluspi.sh` drives all three. It reads [`cluster.yaml`](configuration.md) for settings and `.env` for secrets, and generates the Terraform and Ansible variable files.

## Request path

```
            LAN clients / kubectl
                   │
        k3s.vip (Keepalived VIP, HAProxy :6443)
          ┌────────┴────────┐
   control LB 1          control LB 2
          └────────┬────────┘
     ┌─────────────┼──────────────┐
  main control   control nodes   (k3s servers, datastore = ETCD or external MySQL)
     └─────────────┬──────────────┘
                workers (k3s agents)

  metallb.ip_range → Traefik LoadBalancer service (servicelb is disabled)
```

## Repository layout

```
cluspi/
├── README.md                    # Quick install and upgrade
├── cluspi.sh                    # Entry point: deploy, uninstall, destroy
├── cluster.yaml.example         # Template for cluster.yaml (copy and edit)
├── .env_sample                  # Template for .env (secrets only)
├── TODO.md                      # Known issues and planned work
├── requirements.txt             # Python deps for the ./dev venv
├── docs/                        # Documentation (start at docs/index.md)
├── scripts/
│   ├── init_cluster.sh          # Wizard: writes cluster.yaml and .env
│   ├── config.sh                # Loads and validates cluster.yaml (needs yq)
│   ├── terraform_templates.sh   # Generates terraform-proxmox/terraform.tfvars
│   ├── terraform_fns.sh         # Helpers that format lists for Terraform
│   ├── ansible_templates.sh     # Generates k3s-cluster/group_vars/all.yml and inventory/hosts.yml
│   ├── ansible_fns.sh           # Python venv helpers
│   └── validation.sh            # Checks SSH is up on all nodes before Ansible runs
├── terraform-proxmox/
│   ├── provider.tf              # Providers (telmate/proxmox, hashicorp/http), GitHub key lookup
│   ├── variables.tf             # Input variables
│   ├── node_control_lb.tf       # 2x HAProxy/Keepalived VMs
│   ├── node_control.tf          # Control-plane k3s VMs
│   └── node_worker.tf           # Worker k3s VMs
├── k3s-cluster/
│   ├── install.yml              # Playbook: full install
│   ├── uninstall.yml            # Playbook: full uninstall (VMs are left intact)
│   ├── inventory/               # hosts.yml is generated (gitignored)
│   ├── group_vars/              # all.yml is generated (gitignored)
│   └── roles/
│       ├── control_lb/          # HAProxy + Keepalived in front of the control plane
│       ├── main_control/        # First control node: k3s server init, Traefik config, token
│       ├── control_node/        # Additional control nodes (join the first one)
│       ├── worker_node/         # Worker nodes (k3s agent)
│       ├── metallb/             # MetalLB (LoadBalancer IPs from metallb.ip_range)
│       ├── dev_machine/         # Fetches kubeconfig to ~/.kube/config, installs kubectl + helm
│       ├── cert_manager/        # cert-manager via Helm
│       └── rancher/             # Rancher via Helm (only when addons.rancher.install is true)
└── packer/proxmox/              # Builds the Ubuntu 24.04 cloud-init template on Proxmox
```

## Node types: `PROX` and `EXT`

- **`PROX`**: Terraform creates the VM on Proxmox from the template. It needs a Proxmox `target` node.
- **`EXT`**: the VM already exists. Terraform skips it and Ansible configures it. It needs the `user.vm_user` account, SSH key access and passwordless sudo.

See [configuration.md](configuration.md) for how to set them.
