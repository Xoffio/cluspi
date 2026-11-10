# Build the VM template (Packer)

Use this only if you don't already have a cloud-init Ubuntu template on Proxmox.

```bash
cd packer/proxmox
export PM_API_URL=https://prox01.lan:8006/api2/json
export PM_API_TOKEN_ID='terraform-prov@pve!terraform-token'
export PM_API_TOKEN_SECRET='...'

packer init .
packer build \
  -var "node_name=prox01" \
  -var "ssh_username=<VM_USER>" \
  -var "autoinstall_ip=<your workstation IP>" \
  .
```

Before building:

- Set the username in `packer/proxmox/http-files/user-data` (replace `USERNAME-HERE`) and add your SSH key to it.
- The build reads `PM_API_*` from the environment and uses `~/.ssh/id_rsa` for its first SSH connection.

After building, set `proxmox.template` in `cluster.yaml` to the name of the template. The Packer template's `vm_name` is `ubuntu-server-2404`, so make sure the name matches what's in Proxmox. See [known-gaps.md](../known-gaps.md).

## Updating the template

Rebuild under a new name, then update `proxmox.template`. Existing VMs keep the template they were cloned from. To roll out a new OS image, replace the VMs one at a time (drain the node, remove it, deploy it again) rather than changing the template in place.
