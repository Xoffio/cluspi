# Rancher upgrades

A short reference for upgrading Rancher on this cluster. The example at the end is what was actually done here.

## Why the upgrades are done this way

**Rancher and k3s have to move together.** SUSE certifies each Rancher release for a specific range of k3s versions. Rancher 2.14 needs k3s 1.33 or newer. Rancher 2.15 needs k3s 1.34 or newer. The ranges move forward one minor version at a time, so a k3s upgrade is needed before the Rancher upgrade that depends on it.

Check the [support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/) before each step. The range for your target version is what matters, not this table.

**One minor version at a time.** Rancher only supports moving from the latest patch of one minor release to the latest patch of the next. Going from 2.12 straight to 2.15 skips steps that the release notes rely on.

**Back up first.** `helm rollback` does not properly undo a Rancher upgrade. If an upgrade goes wrong, the way back is to restore a Rancher backup taken before the upgrade. Without a backup, there is no safe way back.

## The rules

1. One minor version per step, latest patch each time.
2. Raise the k3s version before the Rancher step that needs it.
3. Back up before every step.
4. Update `cluster.yaml` after each step, so the next run matches what's running.
5. Check the result before continuing.

## The steps

```bash
# 1. Check the environment
./cluspi.sh --check -d EDB
./cluspi.sh --dry-run -d EDB

# 2. Install the backup operator (once), take a backup, dump the database

# 3. Raise the k3s version if the next Rancher release needs it
yq -i '.k3s.version = "1.33.12+k3s1"' cluster.yaml
./cluspi.sh -d EDB --skip-vms

# 4. Raise the Rancher version
yq -i '.addons.rancher.version = "2.14.3"' cluster.yaml
./cluspi.sh -d EDB --skip-vms

# 5. Verify, then update the version in cluster.yaml (already done by yq above)
helm -n cattle-system list | grep rancher
kubectl -n cattle-system rollout status deploy/rancher
```

**Two things to get right in `cluster.yaml`:**

## Example: what was done on this cluster

Starting point: Rancher 2.12.2, k3s v1.32.9+k3s1.

| Step | Command | Result |
|---|---|---|
| 1 | `yq -i '.addons.rancher.version = "2.13.3"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Worked |
| 2 | `yq -i '.k3s.version = "1.33.12+k3s1"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Worked |
| 3 | `yq -i '.addons.rancher.version = "2.14.1"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Worked |
| 4 | `yq -i '.addons.rancher.version = "2.14.3"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Worked |
| 5 | `yq -i '.k3s.version = "1.34.8+k3s1"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Worked |
| 6 | `yq -i '.addons.rancher.version = "2.15.1"' cluster.yaml` then `./cluspi.sh -d EDB --skip-vms` | Failed, then worked. See below. |

Current state: Rancher 2.15.1, k3s v1.34.8+k3s1 on all five nodes.

**Two problems came up along the way.**

**Helm 4 broke the upgrade.** The role failed with `Error: unknown flag: --all`. The Ansible Helm module runs `helm list --all`, and Helm 4 removed that flag. Fixed by installing Helm 3.18.3 at `~/.local/bin/helm`. The role only installs Helm when none is found, so an existing Helm 4 binary is left alone.

**Rancher 2.15.1 wouldn't start on a Pi worker.** The pod landed on `wn01`, an arm64 Raspberry Pi with 3.8 GB of RAM, and crash-looped while restoring the local catalogs:

```
Restoring git repositories:
- /var/lib/rancher-data/local-catalogs/v2/rancher-charts/.../.git
Killing: Container rancher failed startup probe, will be restarted
```

The container was killed with `exit: 137` when the startup probe timed out. Once it ran on the control node `cn02` (12 GB), it started cleanly with 0 restarts. So it's about the node's memory, not the architecture: the 2.15.1 image does have an arm64 build.

**Nothing stops the next upgrade from landing on a Pi again.** Two ways to handle it:

- Give Rancher a memory request, so the scheduler prefers the control nodes. Needs a small change to the Rancher role to pass the value through.
- Taint the worker nodes with `NoSchedule`. Anything without a matching toleration then stays off the Pis. The worker role needs a step to run `kubectl taint` after the agent joins.

## Possible problems

**The upgrade fails with `context deadline exceeded`.** Helm gives up waiting for the pod. Usually the pod isn't becoming ready. Check where it landed:

```bash
kubectl -n cattle-system get pods -o wide
kubectl -n cattle-system logs -f deploy/rancher --tail=50
```

**The Helm release shows `failed` but Rancher is working.** The upgrade command timed out before the pod was ready, but the pod came up later. The cluster is fine. The next `helm upgrade` supersedes that revision and clears it.

**`Error: unknown flag: --all`.** Helm 4 is on the PATH. See above.

**`Download failed` during the k3s upgrade.** The version in `cluster.yaml` has a leading `v`. See above.

**`chart "rancher" matching 2.12.15 not found`.** The `rancher-stable` repo doesn't carry every patch release. Check what's actually there:

```bash
helm repo update rancher-stable
helm search repo rancher-stable/rancher --versions | head -20
```

The `rancher-prime` repo has newer patches (2.12.15, 2.13.11, 2.14.7, 2.15.3), but its chart pulls images from `registry.rancher.com` instead of Docker Hub. Switching to it means changing the repo URL in `roles/rancher/tasks/install.yaml`.

**The webhook's liveness probe fails during the upgrade.** This happened here with `context deadline exceeded` on the healthz endpoint. The webhook pods were replaced during the upgrade. It settled on its own, but it's worth watching.

**There's no backup.** `rancher-backup` was never installed on this cluster. Install it and take a backup before the next upgrade. Without one, a failed upgrade has no safe way back.
