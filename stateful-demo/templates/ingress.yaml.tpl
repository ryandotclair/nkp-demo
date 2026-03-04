apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: csi-demo-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: kommander-traefik
  tls:
    - hosts:
        - __NAMESPACE__.sslip.nutanixdemo.com
      # Use a Secret with tls.crt + tls.key (server cert for *.sslip.nutanixdemo.com), not ca.crt
      secretName: kommander-ingress
  rules:
    - host: __NAMESPACE__.sslip.nutanixdemo.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: csi-demo-app
                port:
                  number: 80
