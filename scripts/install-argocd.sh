#!/bin/bash
set -e

# --- Variablen ---
ARGO_NS="argocd"

echo "🚀 Installing ArgoCD..."

helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGO_NS" \
  --create-namespace

echo "✅ ArgoCD installed successfully."
