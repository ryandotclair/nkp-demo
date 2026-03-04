# Redirect HTTP to HTTPS for this host. Referenced by Ingress annotation.
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
spec:
  redirectScheme:
    scheme: https
    permanent: true
