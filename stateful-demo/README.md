# CSI + Flux Demo (ryan-demo)

Demo: self-service PVCs from StorageClasses via GitOps. One path under `infra/`: start stateless (data lost on pod delete), then add PVCs via a second init pass — that commit is what the audience sees.

## Quick start

**Setup (before demo)** — generate stateless app, commit, push; Flux applies; show data loss on pod delete:
```bash
./stateful-demo/init.sh 10.8.53.16 ryan-demo stateless
```
Commit and push `stateful-demo/infra/`. Point Flux at `stateful-demo/infra/`. App runs with emptyDir; delete the pod and data is gone.

**Demo (what audience sees)** — generate stateful app (PVCs + deployment), commit, push; Flux reconciles; data persists:
```bash
./stateful-demo/init.sh 10.8.53.16 ryan-demo stateful
```
Commit and push the changes to `stateful-demo/infra/`. The **git diff** is what you show: new PVCs and deployment updated to use them. After reconcile, delete the pod again — data is still there.

Init always applies the namespace, logs in to Harbor, and builds/pushes the app image. Registry and ingress host: `nkp-<IP-dashes>.sslip.nutanixdemo.com`, `<namespace>.sslip.nutanixdemo.com`.

## Demo flow

1. **Stateless (setup):** Run init with `stateless`. Commit and push `infra/`. Flux deploys app with emptyDir. Open app, add text, save. `kubectl delete pod -n <namespace> -l app=csi-demo-app` — reload app, data is gone.
2. **Stateful (audience):** Run init with `stateful`. Commit and push — show the **git change** (new `pvc-block.yaml`, `pvc-file.yaml`, updated `deployment.yaml` and `kustomization.yaml`). Flux reconciles; PVCs provision, deployment uses them. Open app, add text, save. Delete pod again — data persists.
3. **Backend mapping:** `kubectl describe pvc -n <namespace>` — point at VolumeHandle / provisioner.

## Optional: Object CSI (later commit)

Add an Object Bucket Claim and a deployment that uses the bucket; commit and push to show the same GitOps flow for object storage.
