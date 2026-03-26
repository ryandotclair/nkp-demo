apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: demo-stripprefix
  namespace: __NAMESPACE__
spec:
  stripPrefix:
    prefixes:
      - /demo
