#!/usr/bin/env bash
set -euo pipefail

# ============================
# CONFIG
# ============================
NAMESPACE="cert-manager"
RELEASE_NAME="cert-manager"
CHART_REPO="https://charts.jetstack.io"
CHART_VERSION="v1.14.4"
VALUES_FILE="${VALUES_FILE:-""}"

echo "🚀 Installing cert-manager (Option A: Clean reset)"

# ============================
# 1. Remove existing CRDs
# ============================
echo "🔍 Checking for existing cert-manager CRDs..."
EXISTING_CRDS=$(kubectl get crds | grep 'cert-manager.io' || true)

if [[ -n "$EXISTING_CRDS" ]]; then
  echo "🧹 Found existing CRDs – deleting them..."
  CRDS=$(echo "$EXISTING_CRDS" | awk '{print $1}')
  for crd in $CRDS; do
    echo "   → deleting $crd"
    kubectl delete crd "$crd" --ignore-not-found
  done
else
  echo "✓ No old CRDs found."
fi

# ============================
# 2. Delete old namespace
# ============================
echo "🔍 Checking for namespace $NAMESPACE..."
if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  echo "🧹 Deleting namespace $NAMESPACE..."
  kubectl delete ns "$NAMESPACE" --ignore-not-found
  echo "⏳ Waiting for namespace to terminate..."
  kubectl wait --for=delete ns/"$NAMESPACE" --timeout=60s || true
else
  echo "✓ Namespace not present."
fi

# ============================
# 3. Remove old Helm release
# ============================
echo "🔍 Checking for previous Helm release..."
if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
  echo "🧹 Helm uninstall $RELEASE_NAME"
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
else
  echo "✓ Helm release not present."
fi

# ============================
# 4. Install CRDs cleanly
# ============================
echo "📦 Installing cert-manager CRDs..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CHART_VERSION}/cert-manager.crds.yaml

# ============================
# 5. Add Helm repo (idempotent)
# ============================
helm repo add jetstack "$CHART_REPO" >/dev/null 2>&1 || true
helm repo update

# ============================
# 6. Install cert-manager with Helm
# ============================
echo "⎈ Installing cert-manager via Helm..."

if [[ -n "$VALUES_FILE" ]]; then
  helm upgrade --install "$RELEASE_NAME" jetstack/cert-manager \
    --namespace "$NAMESPACE" \
    --create-namespace \
    -f "$VALUES_FILE" \
    --version "$CHART_VERSION"
else
  helm upgrade --install "$RELEASE_NAME" jetstack/cert-manager \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION"
fi

echo "🎉 cert-manager installation completed cleanly!"

