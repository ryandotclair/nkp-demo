#!/usr/bin/env bash
# Init script for CSI demo: set registry and namespace, render all infra from templates, apply namespace, build/push image.
# Usage: ./init.sh <IP> <NAMESPACE>
# Example: ./init.sh 10.8.53.16 ryan-demo

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <IP> <NAMESPACE>"
  echo "Example: $0 10.8.53.16 ryan-demo"
  echo "Registry: nkp-<IP-with-dashes>.sslip.nutanixdemo.com:5000/library"
  exit 1
fi

IP="$1"
NAMESPACE="$2"
# Convert 10.8.53.16 -> 10-8-53-16 (accept either form)
IP_DASHED="${IP//./-}"
REGISTRY_HOST="nkp-${IP_DASHED}.sslip.nutanixdemo.com:5000"
REGISTRY_IMAGE="${REGISTRY_HOST}/library/csi-demo-app:latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "Not found: $TEMPLATES_DIR"
  exit 1
fi

echo "Namespace:     $NAMESPACE"
echo "Registry host: $REGISTRY_HOST"
echo "Image:         $REGISTRY_IMAGE"
echo ""

# Generate all infra files from templates (__NAMESPACE__ and __REGISTRY_IMAGE__)
GenerateFromTemplate() {
  local tpl="$1"
  local dest="$2"
  sed -e "s|__NAMESPACE__|$NAMESPACE|g" -e "s|__REGISTRY_IMAGE__|$REGISTRY_IMAGE|g" "$tpl" > "$dest"
  echo "  Generated $(basename "$dest")"
}

echo "Generating infra from templates..."
GenerateFromTemplate "$TEMPLATES_DIR/namespace.yaml.tpl"      "$INFRA_DIR/namespace.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/pvc-block.yaml.tpl"      "$INFRA_DIR/pvc-block.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/pvc-file.yaml.tpl"      "$INFRA_DIR/pvc-file.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/deployment.yaml.tpl"    "$INFRA_DIR/deployment.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/service.yaml.tpl"       "$INFRA_DIR/service.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/ingress.yaml.tpl"      "$INFRA_DIR/ingress.yaml"
GenerateFromTemplate "$TEMPLATES_DIR/kustomization.yaml.tpl" "$INFRA_DIR/kustomization.yaml"
echo ""

# Apply namespace so it exists before Flux (optional, for demo: "look, namespace is there")
echo "Applying namespace $NAMESPACE..."
kubectl apply -f "$INFRA_DIR/namespace.yaml"
echo ""

# Docker login (will prompt for user/pass if needed)
echo "Log in to the registry when prompted."
docker login "$REGISTRY_HOST"
echo ""

# Build for linux/amd64 so the image runs on typical cluster nodes (avoids exec format error on arm64 Macs)
echo "Building image (linux/amd64)..."
docker build --platform linux/amd64 -t "$REGISTRY_IMAGE" -f "$SCRIPT_DIR/app/Dockerfile" "$SCRIPT_DIR/app"
echo ""

echo "Pushing image..."
docker push "$REGISTRY_IMAGE"
echo ""

echo "Done. Next steps:"
echo "  1. git add stateful-demo/infra/"
echo "  2. git commit -m 'Set demo app for namespace $NAMESPACE'"
echo "  3. git push"
echo "  Flux will reconcile and deploy the app."
