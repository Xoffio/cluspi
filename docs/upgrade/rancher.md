# Upgrade Rancher

Rancher is upgraded with Helm, one minor version at a time. Rancher only supports moving from the latest patch of one minor release to the latest patch of the next. Helm rollback does not undo a Rancher upgrade, so take a backup before every step.

The step-by-step plan and log for this cluster are in [../rancher-upgrade-progress.md](../rancher-upgrade-progress.md).

## Check k3s compatibility first

Each Rancher release is certified for a range of k3s versions. Before every Rancher step, check the [Rancher support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/) for the target version, and confirm the k3s version of the cluster that runs Rancher is inside the certified range.

The k3s ranges for the four releases on the path to 2.15:

| Rancher | Certified k3s versions |
|---|---|
| 2.12.15 | v1.31 – v1.33 |
| 2.13.11 | v1.32 – v1.34 |
| 2.14.7 | v1.33 – v1.35 |
| 2.15.3 | v1.34 – v1.36 |

Rancher and k3s often have to be upgraded together. Rancher 2.14 needs k3s 1.33 or newer, and Rancher 2.15 needs k3s 1.34 or newer. Check the matrix again for each target, since these ranges can change.

Check the arch column too. Some k3s versions are listed as x86-only for clusters Rancher provisions, while others list arm64 or mixed. If your cluster has arm64 nodes, check that the target Kubernetes version supports them.

## Install the backup operator (once)

Install `rancher-backup` so you can restore Rancher if an upgrade goes wrong. Pick the chart version that matches your current Rancher minor, and upgrade it alongside Rancher at each step.

```bash
helm repo add rancher-chart https://charts.rancher.io
helm repo update
helm search repo rancher-chart/rancher-backup --versions | head

helm install rancher-backup-crd rancher-chart/rancher-backup-crd \
  -n cattle-resources-system --create-namespace --version <CHART_VERSION>
helm install rancher-backup rancher-chart/rancher-backup \
  -n cattle-resources-system --version <CHART_VERSION> \
  --set persistence.enabled=true --set persistence.storageClass=<STORAGE_CLASS>
```

Store backups off the cluster (S3 or MinIO are supported). A PVC on the default `local-path` storage class sits on one node's disk, which doesn't protect you if that node fails.

Take a backup from the Rancher UI: **☰ → Cluster Management → local → Explore → Backups → Create**. Confirm it completes with `kubectl get backup`.

Also dump the external database, since it holds the k3s cluster state and is outside Rancher's backup:

```bash
mysqldump -h <DB_HOST> -P <DB_PORT> -u <DB_USER> -p <DB_NAME> > k3s-db-$(date +%F).sql
```

## Upgrade path

Run these steps in order. Each Rancher step is followed by a check. The k3s steps are interleaved where the next Rancher release needs them.

1. Back up Rancher and the k3s database.
2. Rancher `2.12.2` → `2.12.15` (k3s `1.32.x` is in range).
3. Rancher `2.12.15` → `2.13.11` (k3s `1.32.x` is in range).
4. k3s `1.32.x` → `1.33.x` → `1.34.x`, one minor at a time, checking the cluster after each. See [k3s.md](k3s.md).
5. Rancher `2.13.11` → `2.14.7` (k3s `1.34.x` is in range).
6. Rancher `2.14.7` → `2.15.3` (k3s `1.34.x` is in range).

Replace `<TARGET>` with the Rancher version for the step, and `1.33.x` / `1.34.x` with the latest patch of each k3s minor.

## Per-step procedure

Before each step:

```bash
helm repo update rancher-stable
helm search repo rancher-stable/rancher --versions | grep "<TARGET_MINOR>."
helm -n cattle-system list
kubectl -n cattle-system get deploy rancher

# Save the values used by the current release
helm -n cattle-system get values rancher -o yaml > ~/rancher-upgrade/values-before.yaml
```

Confirm the latest patch of the current minor is installed. If it isn't, upgrade to that patch first.

Run the upgrade:

```bash
helm upgrade rancher rancher-stable/rancher \
  -n cattle-system \
  -f ~/rancher-upgrade/values-before.yaml \
  --version <TARGET> \
  --wait --timeout 30m
```

Verify it:

```bash
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Open the Rancher UI and check that the `local` cluster is **Active**. In **Apps → Installed Apps**, upgrade any feature charts that are prompting for an update.

Then set `addons.rancher.version` in `cluster.yaml` to the new version.

## Keep `cluster.yaml` in sync with the live release

`./cluspi.sh` applies the Rancher settings from `cluster.yaml` every time it runs: `addons.rancher.version`, `addons.rancher.fqdn` and `addons.rancher.replicas`. If they don't match the live release, a re-run can:

- downgrade Rancher to an older version,
- change the Rancher hostname, which breaks access to the UI,
- change the replica count.

So after every successful step, set `addons.rancher.version` to the version that is running. Check the live values first with `helm -n cattle-system get values rancher` and `helm -n cattle-system list`.

`cluspi.sh` upgrades Rancher in one jump, so never set `addons.rancher.version` to a version more than one minor ahead of the running release.

To upgrade k3s during this process, change `k3s.version` and run the deploy as described in [k3s.md](k3s.md). That only works once `addons.rancher.version` matches the running Rancher version.

## Roll back

Do not use `helm rollback` for Rancher. The safe way back is to reinstall the previous Rancher version and restore the backup taken before the upgrade, using a `Restore` resource from rancher-backup. The backup has to be restored into the Rancher version it was taken from. Check the "Backup/Restore" known issues for that version in the release notes first, since some rollbacks need extra steps such as removing the webhook chart.
