# Troubleshooting

- **Terraform can't reach Proxmox:** check `proxmox.api_url` in `cluster.yaml`. The provider uses `pm_tls_insecure = true`, so self-signed certificates are fine.
- **Terraform asks for `control_node_ips` (or another variable):** `terraform-proxmox/terraform.tfvars` is missing. Run `./cluspi.sh` once, or regenerate the file with the same steps that `cluspi.sh` uses.
- **Terraform says the template is missing:** `proxmox.template` doesn't match a template in Proxmox.
- **Ansible hangs at "Waiting for SSH":** the VM didn't get its IP. Check the VM console in Proxmox and the gateway and DNS settings.
- **Ansible can't use sudo:** the VM user must have passwordless sudo. The Packer `user-data` sets this up.
- **`kubectl` can't reach the API:** check that `k3s.vip` is free and that HAProxy and Keepalived are running on the load balancer VMs.
- **LoadBalancer services stay `<pending>`:** MetalLB needs free IPs in `metallb.ip_range`, on the same subnet as the nodes.
- **`cluster.yaml not found`:** run `./scripts/init_cluster.sh`, or copy `cluster.yaml.example`.
- **`yq is required`:** install mikefarah `yq` v4. The Python `yq` won't work.
