# Upgrade add-ons

Change the version in `cluster.yaml`, then re-run the deploy:

```bash
./cluspi.sh -d EDB
```

| Component | Setting in `cluster.yaml` | Notes |
|---|---|---|
| MetalLB | `metallb.version` | Manifests are re-applied only when they differ. |
| cert-manager | `addons.cert_manager_version` | Helm upgrade. Check the cert-manager upgrade notes for CRD changes. |
| Rancher | `addons.rancher.version` | Don't jump across minor versions in one step. See [rancher.md](rancher.md). |
| Helm (on your workstation) | `addons.helm_version` | Only installed if `helm` isn't already on the `PATH`. |

Helm 3 is what the Rancher docs assume. If the `helm` on your `PATH` is version 4, install Helm 3 alongside it for Rancher upgrades.
