# Self-service PVC from block StorageClass (CSI block backend).
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-block-pvc
  namespace: __NAMESPACE__
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nutanix-volume
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
