# CSI + Flux Demo (ryan-demo)

Demo: self-service PVCs from StorageClasses via GitOps. One app, two volumes (block + file CSI).

## Quick start

**One-time init (per environment)**  
From the repo root, run the init script with **IP** (Harbor/NKP UI) and **namespace**:
```bash
./stateful-demo/init.sh 10.8.53.16 ryan-demo
```
Init will: generate all files in `infra/` from `templates/` (substituting `__NAMESPACE__` and `__REGISTRY_IMAGE__`), apply the namespace with `kubectl apply -f infra/namespace.yaml`, log in to Harbor, build and push the app image. Registry is `nkp-<IP-with-dashes>.sslip.nutanixdemo.com:5000/library`. Ingress host is `<namespace>.sslip.nutanixdemo.com`. Then commit `stateful-demo/infra/` and push so Flux deploys.

## Demo flow

- **Before:** `watch kubectl get pvc,pods,svc -n <namespace>` → nothing (or no resources).
- **Commit and push** the infra (and app image reference).
- **After reconcile:** Same command shows PVCs Bound, pod Running, Service and Ingress created.
- **Open the app URL** and use “Save to block” and “Save to file” to prove both volumes work.
- **Backend mapping:** `kubectl describe pvc -n <namespace>` and point at `VolumeHandle` / provisioner to show how each PVC maps to storage.

## Optional: Object CSI (second commit)

Add an Object Bucket Claim (OBC) and a deployment that uses the bucket; commit and push to show the same GitOps flow for object storage.
