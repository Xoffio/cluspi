# Rancher upgrade progress

**Goal:** upgrade Rancher from `2.12.2` to `2.15.3` on the cluspi k3s cluster.
**Procedure:** see [Upgrading Rancher](upgrade/rancher.md).
**Last updated:** 2026-11-08

## Starting state (read from the cluster on 2026-11-08)

| Item | Value |
|---|---|
| Control nodes | `cn01`, `cn02`, `cn03` (`cn03` is arm64 Raspberry Pi) |
| Worker nodes | `wn01`, `wn02` (arm64 Raspberry Pi) |
| k3s | `v1.32.9+k3s1` on all nodes |
| Datastore | external MySQL (`K3S_DATASTORE=EDB`) |
| Rancher | chart `rancher-2.12.2`, 1 replica |
| Rancher values | `hostname: cluspi.cluster`, `replicas: "1"` |
| Rancher ingress | `cattle-system/rancher` (Traefik, `192.168.8.150`) |
| Rancher-related charts | `rancher-webhook 107.0.2+up0.8.2`, `rancher-provisioning-capi 107.0.0+up0.8.0`, `fleet 107.0.2+up0.13.2`, `system-upgrade-controller 107.0.0` |
| cert-manager | `v1.19.0` |
| rancher-backup | **not installed** (no `cattle-resources-system` namespace) |
| Old `rancher-rancher-prime` ingress | **not present** |

### `.env` drift (fix before running `./cluspi.sh`)

| Variable | `.env` | Live | Risk |
|---|---|---|---|
| `RANCHER_FQDN` | `cluspi.lan` | `cluspi.cluster` | A re-run changes the Rancher hostname and breaks the UI |
| `RANCHER_N_REPLICAS` | `2` | `1` | A re-run changes the replica count |
| `RANCHER_VER` | `2.12.2` | `2.12.2` | Keep in sync after every step |

No changes have been made to `.env` yet.

## Compatibility (from the Rancher support matrix)

| Rancher | Certified k3s | Our k3s during the step |
|---|---|---|
| 2.12.15 | v1.31 – v1.33 | 1.32.9 ✅ |
| 2.13.11 | v1.32 – v1.34 | 1.32.9 ✅ (1.33 and 1.34 are also in range) |
| 2.14.7 | v1.33 – v1.35 | needs 1.33+ before the step |
| 2.15.3 | v1.34 – v1.36 | needs 1.34+ before the step |

## Plan and status

| # | Action | Rancher | k3s | Status |
|---|---|---|---|---|
| 0 | Fix `.env` drift (`RANCHER_FQDN`, `RANCHER_N_REPLICAS`) | 2.12.2 | 1.32.9 | ☐ |
| 1 | Install rancher-backup operator | 2.12.2 | 1.32.9 | ☐ |
| 2 | Take a Rancher backup and copy it off-cluster | 2.12.2 | 1.32.9 | ☐ |
| 3 | Dump the k3s MySQL database | 2.12.2 | 1.32.9 | ☐ |
| 4 | Rancher → 2.12.15 (latest 2.12 patch) | 2.12.15 | 1.32.9 | ☐ |
| 5 | Rancher → 2.13.11 (latest 2.13 patch), verify | 2.13.11 | 1.32.9 | ☐ |
| 6 | k3s → 1.33.x (latest patch), verify | 2.13.11 | 1.33.x | ☐ |
| 7 | k3s → 1.34.x (latest patch), verify | 2.13.11 | 1.34.x | ☐ |
| 8 | Rancher → 2.14.7 (latest 2.14 patch), verify | 2.14.7 | 1.34.x | ☐ |
| 9 | Rancher → 2.15.3, verify | 2.15.3 | 1.34.x | ☐ |
| 10 | Post-upgrade: new backup, update `.env` (`RANCHER_VER=2.15.3`) | 2.15.3 | 1.34.x | ☐ |

Each step is complete when: the Rancher deployment rolls out, the `local` cluster shows **Active** in the UI, the installed Rancher charts are updated, and `RANCHER_VER` in `.env` matches the running version.

## Things to check before each step

- [ ] The target Rancher version is in the support matrix for the current k3s version.
- [ ] You are on the latest patch of the current Rancher minor.
- [ ] A backup from this stage completed (`kubectl get backup`).
- [ ] `helm -n cattle-system get values rancher` matches what you expect (`hostname: cluspi.cluster`, `replicas: 1`).

## Findings

- **Ingress conflict (2.13.1 → 2.13.2).** The Rancher docs describe a conflict with an old `rancher-rancher-prime` Ingress. It was caused by the temporary chart rename in Rancher 2.13.1, which 2.13.2 reverted. Our cluster was installed with the `rancher` chart and has no `rancher-rancher-prime` Ingress, so this shouldn't affect us. Re-check with `kubectl get ingress -A | grep rancher-rancher-prime` before the 2.15.3 step.
- **Aggregation layer.** The 2.15.x release notes say Rancher requires the Kubernetes API aggregation layer. k3s enables it by default. Confirm nothing has disabled it before step 9.
- **2.15.0 known issue.** Upstream issue [rancher/rancher#56522](https://github.com/rancher/rancher/issues/56522) reports 2.15.0 crash-looping with a settings admission webhook error. Read its status against the 2.15.3 release notes before step 9.
- **cert-manager.** We run `v1.19.0`. Check the Rancher Helm requirements for 2.15.3 before step 9 and upgrade cert-manager if it asks for a newer version.
- **Downstream clusters.** None are imported or provisioned in this cluster, as far as the Helm release list shows. Check **Cluster Management** in the UI before each step in case any were added.
- **Architecture.** `cn03`, `wn01` and `wn02` are arm64. Check the arch column for each target k3s version.

## Log

- **2026-11-08:** Read the Rancher support matrices, upgrade docs and the 2.15.3 release notes. Read cluster state (nodes, Helm releases, Rancher values, ingresses). Wrote the README section and this progress file. **No changes made to the cluster.**
- **2026-11-08:** `.env` review. User fixed control/worker IPs and names, `RANCHER_FQDN`, `RANCHER_N_REPLICAS`, gateway, DNS, `VM_USER=loco`, `GITHUB_USER`. Datastore confirmed on `cn01`: external MySQL at `rmnas.opt2:3306`, user `root`, database `k3s_v01`. Assistant set `DB_HOST`, `DB_USER` and `DB_NAME` to these values. Assistant changed `CONTROL_NODE_NAMES` to `cn01,cn02,cn03`, `CONTROL_NODE_TYPES` to `EXT,EXT,EXT` (cn01/cn02 are existing VMs with no Terraform state; cn03 is a Pi), and `PM_API_URL` to `prox01.opt2`. Proxmox API returns 401 for the current token, so it needs fixing. Still open: `DB_HOST`, `DB_USER`, LB VM status, Proxmox token.
