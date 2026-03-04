#!/usr/bin/env bash
# Init script for CSI demo: render infra/ from templates (stateless or stateful), optionally apply namespace and build/push image.
# Usage: ./init.sh <IP> <NAMESPACE> <stateless|stateful>
#   stateless — setup: app with emptyDir (no PVCs). Commit this first; Flux applies; show data lost on pod delete.
#   stateful  — demo: add PVCs and deployment using them. Commit this; audience sees the git change; Flux reconciles, data persists.
# Example: ./init.sh 10.8.53.16 ryan-demo stateless   (then later)   ./init.sh 10.8.53.16 ryan-demo stateful

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 <IP> <NAMESPACE> <stateless|stateful>"
  echo "  stateless — app only (emptyDir). Use for initial setup; commit and push; then run stateful for the demo."
  echo "  stateful  — app + PVCs. Use for demo; commit and push so audience sees the git change."
  echo "Example: $0 10.8.53.16 ryan-demo stateless"
  exit 1
fi

MODE="$3"
if [ "$MODE" != "stateless" ] && [ "$MODE" != "stateful" ]; then
  echo "Mode must be 'stateless' or 'stateful'"
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
echo "Mode:          $MODE"
echo ""

# Generate file from template (__NAMESPACE__ and __REGISTRY_IMAGE__)
GenerateFromTemplate() {
  local tpl="$1"
  local dest="$2"
  sed -e "s|__NAMESPACE__|$NAMESPACE|g" -e "s|__REGISTRY_IMAGE__|$REGISTRY_IMAGE|g" "$tpl" > "$dest"
  echo "  $(basename "$dest")"
}

# Clear infra/ so switching stateless <-> stateful leaves no leftover files
rm -rf "$INFRA_DIR"
mkdir -p "$INFRA_DIR"

if [ "$MODE" = "stateless" ]; then
  echo "Generating infra/ (stateless — app only, emptyDir, no PVCs)..."
  GenerateFromTemplate "$TEMPLATES_DIR/namespace.yaml.tpl"             "$INFRA_DIR/namespace.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/deployment-step1.yaml.tpl"      "$INFRA_DIR/deployment.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/service.yaml.tpl"               "$INFRA_DIR/service.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/ingress.yaml.tpl"               "$INFRA_DIR/ingress.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/kustomization-stateless.yaml.tpl" "$INFRA_DIR/kustomization.yaml"
else
  echo "Generating infra/ (stateful — app + PVCs)..."
  GenerateFromTemplate "$TEMPLATES_DIR/namespace.yaml.tpl"             "$INFRA_DIR/namespace.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/pvc-block.yaml.tpl"            "$INFRA_DIR/pvc-block.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/pvc-file.yaml.tpl"             "$INFRA_DIR/pvc-file.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/deployment.yaml.tpl"           "$INFRA_DIR/deployment.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/service.yaml.tpl"               "$INFRA_DIR/service.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/ingress.yaml.tpl"               "$INFRA_DIR/ingress.yaml"
  GenerateFromTemplate "$TEMPLATES_DIR/kustomization-stateful.yaml.tpl" "$INFRA_DIR/kustomization.yaml"
fi
echo ""

# Apply namespace so it exists before Flux
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

if [ "$MODE" = "stateless" ]; then
  echo "Done (stateless). Next: commit and push stateful-demo/infra/, point Flux at stateful-demo/infra/. Show app, delete pod, data is gone."
  echo "Then run: $0 $IP $NAMESPACE stateful   and commit/push again — that's the git change the audience sees."
else
  echo "Done (stateful). Commit and push stateful-demo/infra/ — audience sees the diff (PVCs + deployment update). Flux reconciles; data now persists."
fi
