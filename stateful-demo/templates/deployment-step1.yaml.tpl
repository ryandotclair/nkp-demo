# App with emptyDir — data is lost when the pod is deleted.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-demo-app
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
          emptyDir: {}
        - name: file-storage
          emptyDir: {}
