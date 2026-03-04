# CSI + Flux Demo (ryan-demo)

Demo: self-service PVCs from StorageClasses via GitOps. One path under `infra/`: start stateless (data lost on pod delete), then add PVCs via a second init pass — that commit is what the audience sees.

## Demo Setup
1. Use `NKP Deployment` runbook
1. Install Harbor from the NKP App Catalog
  1. Default password can be found with `kubectl get secrets -n ncr-system harbor-admin-password -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d`
1. Create a Project for yourself
1. Copy the `secret/kommander-ingress` from the mgmt cluster, apply it to your Project's namespace on the workload cluster
1. Fork this repo
1. Leverage the init.sh script to generate stateless app, using NKP's mgmt VIP (aka IP used to access NKP UI and Harbor):
```bash
# syntax: init.sh <ip> <namespace> <stateless>
./stateful-demo/init.sh 10.8.53.16 ryan-demo stateless
```
1. Commit and push. 
> Note: App runs with emptyDir; delete the pod and data will go with it.
1. Add your new repo to the Project (CD)
1. Add `<IP> <namespace>.sslip.nutanixdemo.com` to your `/etc/hosts` local file. Example:
```
10.8.53.19 ryan-demo.sslip.nutanixdemo.com
```
1. Test that it works by heading to `<namespace>.sslip.nutanixdemo.com` in your browser, adding data to it, then run
`kubectl delete pod -n <namespace> -l app=csi-demo-app` on the workload cluster.
1. Just before demo run the stateful command to have things "ready" to commit, which will turn what's currently running stateful:
```bash
# init.sh <ip> <namespace> <stateful>
./stateful-demo/init.sh 10.8.53.16 ryan-demo stateful
```
1. Also recommend having the `watch kubectl get pvc,pods,svc,ingress -n <namespace>` command running in a separate window.

## Pro Tip
- `alias forceflux='flux reconcile source git stateful-demo -n ryan-demo && flux reconcile kustomization stateful-demo -n ryan-demo'`
   - This gives you a `forceflux` command that effectively forces flux to take recent git commit NOW... there's a short delay normally.

## The Demo
1. Show the simple web app, add data to both Block and File. 
1. Delete the app with `kubectl delete pod -n <namespace> -l app=csi-demo-app`, highlight the pod name in the website just before you refresh. Show that data was deleted.
1. Show the changes you've added (pvcs, and deployment)
1. Show the storageclasses already there (`kubectl get sc`)
1. Commit and push the changes. If you have a second screen, run `forceflux` to trigger an immediate reconciliation. 
1. Highlight the benefits of gitops, and a call out to NKP's CD feature.
1. Highlight the new pod that was deployed, refresh browser, notice they match. Add data to it.
1. Kill the pod again.
1. Highlight how it's taking longer because it first has to release the volume from the terminating pod, then attaching it to the new one. The benefit to that though is when it comes up (highlight pod new pod name and refresh), the data persists.
1. Quick shout out on Snapshots and Clone support. 
1. Also highlight COSI for object storage (in NKP UI)
1. As well as NDK from a DR (sync/async of all these kubernetes objects to another cluster)
