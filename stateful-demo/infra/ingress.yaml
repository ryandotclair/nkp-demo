apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: csi-demo-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: kommander-traefik
  rules:
    - http:
        paths:
          - path: /demo
            pathType: Prefix
            backend:
              service:
                name: csi-demo-app
                port:
                  number: 80
