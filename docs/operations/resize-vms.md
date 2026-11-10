# Resize VMs

Each `PROX` node can set its own size in `cluster.yaml`. Anything it leaves out uses the role default under `resources`:

```yaml
resources:
  control:
    cores: 2
    ram: 2048   # MB
    disk: 32    # GB

control_nodes:
  - name: cn01
    type: PROX
    ip: 192.168.1.101/24
    target: prox01
    cores: 6
    ram: 24576
```

Then re-run the deploy. Terraform updates the VMs in place where Proxmox allows it.

## Rules

- **Disks can only grow.** Shrinking `disk` makes Terraform fail, so don't do it.
- **Check the plan first.** Run `terraform plan` from `terraform-proxmox/` and look for changes to `memory`, `cores` or `disk`. A value in `cluster.yaml` that doesn't match a running VM will show up as a change, and applying it changes that VM.
- **Restart if Proxmox asks.** Some changes need a reboot.
- **Load balancers and `EXT` nodes** don't use these settings. Terraform doesn't manage `EXT` VMs, and the load balancers have fixed sizes.
