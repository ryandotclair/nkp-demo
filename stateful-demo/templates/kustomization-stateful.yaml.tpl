# Stateful: app + PVCs (block + file).
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: __NAMESPACE__
resources:
  - namespace.yaml
  - pvc-block.yaml
  - pvc-file.yaml
  - deployment.yaml
  - service.yaml
  - middleware.yaml
  - ingress.yaml
