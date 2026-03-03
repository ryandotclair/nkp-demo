apiVersion: v1
kind: Service
metadata:
  name: csi-demo-app
  namespace: __NAMESPACE__
spec:
  selector:
    app: csi-demo-app
  ports:
    - port: 80
      targetPort: 8080
      name: http
  type: ClusterIP
