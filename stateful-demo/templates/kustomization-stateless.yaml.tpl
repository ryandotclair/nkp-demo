# Stateless: app only (emptyDir). Use with init.sh <IP> <NAMESPACE> stateless for setup.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: __NAMESPACE__
resources:
  - namespace.yaml
  - middleware-redirect-https.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
