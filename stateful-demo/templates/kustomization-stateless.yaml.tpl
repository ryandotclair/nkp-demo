# Stateless: app only (emptyDir).
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: __NAMESPACE__
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
