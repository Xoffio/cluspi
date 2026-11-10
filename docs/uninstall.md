# Uninstall and destroy

| Command | What it does | VMs |
|---|---|---|
| `./cluspi.sh -u` | Uninstalls k3s, MetalLB, cert-manager, Rancher and HAProxy/Keepalived. With `EDB`, also drops the database. | Left running |
| `./cluspi.sh -x` | Runs the uninstall above, then `terraform destroy` on the VMs. | Deleted (Terraform asks for confirmation) |

Uninstall needs the same `cluster.yaml` and `.env` that were used to deploy.
