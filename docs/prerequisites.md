# Prerequisites

## On Proxmox

- A Proxmox node with an API token that can create and manage VMs. Create it under *Datacenter → Permissions → API Tokens*. Its ID and secret go in `.env`.
- A cloud-init Ubuntu template to clone. Its name goes in `proxmox.template` in `cluster.yaml`. See [operations/build-template.md](operations/build-template.md) if you need to build one.
- Free static IPs for every control node, worker and load balancer, plus a free IP for the control-plane VIP (`k3s.vip`) and a free range for MetalLB (`metallb.ip_range`). They must all be on the LAN that the gateway serves.

## On your workstation

- `bash`, `python3` (with `venv`), `nc` (netcat) and `ssh`.
- [`yq`](https://github.com/mikefarah/yq), version 4. The scripts use it to read `cluster.yaml`. The Python `yq` is a different tool and won't work.
- `terraform` 1.0.0 or newer.
- An SSH key registered on your GitHub account. Terraform reads `https://github.com/<github_user>.keys` and puts those keys on every VM. Ansible then connects with your key.
- Optional: `packer`, if you want to build the template.

The Python dependencies for Ansible are installed automatically into `./dev` on the first run. The `kubernetes.core` and `community.mysql` collections come with the `ansible` package.

## Access to the VMs

The user in `user.vm_user` must:
- exist on the template or on the `EXT` VMs,
- accept your SSH key,
- have passwordless `sudo`.
