#!/bin/bash
set -e

# --- Variablen ---
CERT_NS="cert-manager"

echo "🚀 Installing cert-manager..."

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io || true
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace "$CERT_NS" \
  --create-namespace \
  --set installCRDs=true

echo "✅ cert-manager installed successfully."
