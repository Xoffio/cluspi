# cluspi documentation

Start with the [README](../README.md) for a quick install and upgrade.

## Setup

- [Prerequisites](prerequisites.md): what you need on Proxmox and on your workstation.
- [Configuration](configuration.md): `cluster.yaml`, `.env`, `PROX` vs `EXT` nodes, and the setup wizard.
- [Install](install.md): choosing a datastore, running the deploy, and verifying the cluster.
- [Architecture](architecture.md): components, the request path, and the repository layout.

## Upgrades

- [k3s](upgrade/k3s.md)
- [Add-ons: MetalLB, cert-manager, Helm](upgrade/add-ons.md)
- [Rancher](upgrade/rancher.md), with the step-by-step progress log in [rancher-upgrade-progress.md](rancher-upgrade-progress.md)

## Operations

- [Resize VMs](operations/resize-vms.md)
- [Add nodes](operations/add-nodes.md)
- [Pre-flight checks, dry runs and `--skip-vms`](operations/preflight.md)
- [Build the VM template (Packer)](operations/build-template.md)
- [Uninstall and destroy](uninstall.md)

## Reference

- [Troubleshooting](troubleshooting.md)
- [Known gaps](known-gaps.md)
