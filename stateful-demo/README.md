# CSI + Flux Demo

Demo: Highlights NKP GitOps feature and CSI Driver (File/Block)

# Assumptions

1. `/demo` route is available (Traefik)
2. `nutanix-volumes` and `nutanix-files` storage class exists (modify `pvc-block.yaml.tpl` and `pvc-file.yaml.tpl` if using different names)
3. `kubectl` is pointed to the cluster you are deploying this to.

## Demo Setup

4. Fork this repo
5. Leverage the init.sh script to generate stateless app, using the first IP in your MetalLB address, the Project/Namespace name you want to deploy this too (ex: `csi-driver` below), and initially use "stateless"

```bash
# syntax: init.sh <ip> <namespace> <stateless>
./stateful-demo/init.sh 10.8.53.16 csi-driver stateless
```

6. Commit and push.

> Note: App runs with emptyDir (local filesystem)

7. Add your new repo to the Project (CD), ensure the path is to `stateful-demo`.

8. Test that it works by heading to `https://<ip>/demo` in your browser, adding data to it, then run

`kubectl delete pod -n <namespace> -l app=csi-demo-app`.

9. Just before demo run the stateful command to have things "ready" to commit, which will turn what's currently running stateful:

```bash
# init.sh <ip> <namespace> <stateful>
./stateful-demo/init.sh 10.8.53.16 csi-driver stateful
```

10. Also recommend having the `watch kubectl get pvc,pods,svc,ingress -n <namespace>` command running in a separate window.

## Pro Tip

- `alias forceflux='flux reconcile source git stateful-demo -n csi-driver && flux reconcile kustomization stateful-demo -n csi-driver'`
  - This gives you a `forceflux` command that effectively forces flux to take recent git commit NOW... there's a short delay normally.

## The Demo

1. Show the simple web app, add data to both Block and File.
2. Delete the app with `kubectl delete pod -n <namespace> -l app=csi-demo-app`, highlight the pod name in the website just before you refresh. Show that data was deleted.
3. Show the changes you've added (pvcs, and deployment)
4. Show the storageclasses already there (`kubectl get sc`)
5. Commit and push the changes. If you have a second screen, run `forceflux` to trigger an immediate reconciliation.
6. Highlight the new pod that was deployed, refresh browser, notice they match. Add data to it.
7. Kill the pod again.
8. Highlight how it's taking longer because it first has to release the volume from the terminating pod, then attaching it to the new one. The benefit to that though is when it comes up (highlight pod new pod name and refresh), the data persists.
9. Quick shout out on Snapshots and Clone support.
10. Also highlight COSI for object storage (in NKP UI)
11. As well as NDK from a DR (sync/async of all these kubernetes objects to another cluster)

