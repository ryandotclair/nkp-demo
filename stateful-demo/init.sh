#!/usr/bin/env bash
# Init script for CSI demo: render infra/ from templates (stateless or stateful), optionally apply namespace and build/push image.
# Usage: ./init.sh [--docker] <REGISTRY_PATH> <NAMESPACE> <stateless|stateful>
#   REGISTRY_PATH — image prefix (no trailing slash): host[:port]/project, e.g. 10.1.1.1:5000/library or registry.example.com/library
#   Registry login uses the host[:port] part only (substring before the first /).
#   --docker — use Docker instead of Podman (default: Podman).
#   With Podman, login/build/push use --tls-verify=false (lab / self-signed registries).
#   stateless — setup: app with emptyDir (no PVCs). Commit this first; Flux applies; show data lost on pod delete.
#   stateful  — demo: add PVCs and deployment using them. Commit this; audience sees the git change; Flux reconciles, data persists.
# Example: ./init.sh 10.8.53.16:5000/library csi-demo stateless
# Example: ./init.sh --docker 10.8.53.16:5000/library csi-demo stateful

set -e

USE_DOCKER=false
RUNTIME_FLAGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --docker)
      USE_DOCKER=true
      RUNTIME_FLAGS=" --docker"
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [--docker] <REGISTRY_PATH> <NAMESPACE> <stateless|stateful>"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$USE_DOCKER" = true ]; then
  CTR=docker
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found on PATH"
    exit 1
  fi
else
  CTR=podman
  if ! command -v podman >/dev/null 2>&1; then
    echo "podman not found on PATH (install Podman or pass --docker to use Docker)"
    exit 1
  fi
fi

# Podman only: disable TLS verification for registry operations (Harbor with self-signed cert, etc.).
if [ "$CTR" = podman ]; then
  PODMAN_TLS=(--tls-verify=false)
else
  PODMAN_TLS=()
fi

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 [--docker] <REGISTRY_PATH> <NAMESPACE> <stateless|stateful>"
  echo "  Default engine: podman. Use --docker for Docker."
  echo "  REGISTRY_PATH — e.g. 10.1.1.1:5000/library or registry.example.com/library (image will be PATH/csi-demo-app:TAG)."
  echo "  stateless — app only (emptyDir). Use for initial setup; commit and push; then run stateful for the demo."
  echo "  stateful  — app + PVCs. Use for demo; commit and push so audience sees the git change."
  echo "Example: $0 10.8.53.16:5000/library ryan-demo stateless"
  echo "Example: $0 --docker 10.8.53.16:5000/library ryan-demo stateless"
  exit 1
fi

# Trim trailing slash; image is REGISTRY_PATH/csi-demo-app:tag (project/path is whatever the user passed).
REGISTRY_PATH="${1%/}"
NAMESPACE="$2"
MODE="$3"

# Host for registry login: everything before the first / (host[:port] only).
if [[ "$REGISTRY_PATH" == */* ]]; then
  REGISTRY_LOGIN_HOST="${REGISTRY_PATH%%/*}"
else
  REGISTRY_LOGIN_HOST="$REGISTRY_PATH"
fi

if [ "$MODE" != "stateless" ] && [ "$MODE" != "stateful" ]; then
  echo "Mode must be 'stateless' or 'stateful'"
  exit 1
fi

if [ "$MODE" = "stateless" ]; then
  REGISTRY_IMAGE="${REGISTRY_PATH}/csi-demo-app:stateless"
else
  REGISTRY_IMAGE="${REGISTRY_PATH}/csi-demo-app:stateful"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "Not found: $TEMPLATES_DIR"
  exit 1
fi

echo "Registry path:   $REGISTRY_PATH"
echo "Registry login:  $REGISTRY_LOGIN_HOST"
echo "Container tool:  $CTR"
echo "Namespace:       $NAMESPACE"
echo "Image:           $REGISTRY_IMAGE"
echo "Mode:            $MODE"
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

# Login (will prompt for user/pass if needed)
echo "Log in to the registry when prompted ($CTR login)."
"$CTR" login "${PODMAN_TLS[@]}" "$REGISTRY_LOGIN_HOST"
echo ""

# Build for linux/amd64; stateless uses app-stateless.py, stateful uses app.py
echo "Building image (linux/amd64) — $MODE..."
if [ "$MODE" = "stateless" ]; then
  "$CTR" build "${PODMAN_TLS[@]}" --platform linux/amd64 -t "$REGISTRY_IMAGE" -f "$SCRIPT_DIR/app/Dockerfile.stateless" "$SCRIPT_DIR/app"
else
  "$CTR" build "${PODMAN_TLS[@]}" --platform linux/amd64 -t "$REGISTRY_IMAGE" -f "$SCRIPT_DIR/app/Dockerfile" "$SCRIPT_DIR/app"
fi
echo ""

echo "Pushing image..."
"$CTR" push "${PODMAN_TLS[@]}" "$REGISTRY_IMAGE"
echo ""

if [ "$MODE" = "stateless" ]; then
  echo "Done (stateless). Next: commit and push stateful-demo/infra/, point Flux at stateful-demo/infra/. Show app, delete pod, data is gone."
  echo "Then run: $0${RUNTIME_FLAGS} '$REGISTRY_PATH' $NAMESPACE stateful   and commit/push again — that's the git change the audience sees."
else
  echo "Done (stateful). Commit and push stateful-demo/infra/ — audience sees the diff (PVCs + deployment update). Flux reconciles; data now persists."
fi
