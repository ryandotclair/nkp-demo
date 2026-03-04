# Generated from stateful-demo/templates/deployment.yaml.tpl by init.sh — do not edit by hand.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-demo-app
  namespace: __NAMESPACE__
  labels:
    app: csi-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: csi-demo-app
  template:
    metadata:
      labels:
        app: csi-demo-app
    spec:
      containers:
        - name: app
          image: __REGISTRY_IMAGE__
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: block-storage
              mountPath: /data/block
            - name: file-storage
              mountPath: /data/file
      volumes:
        - name: block-storage
          persistentVolumeClaim:
            claimName: demo-block-pvc
        - name: file-storage
          persistentVolumeClaim:
            claimName: demo-file-pvc
