#!/bin/bash
set -e

# --- Variablen ---
PROJECT_DIR="$HOME/kubernetes"
INGRESS_DIR="$PROJECT_DIR/clusters/minikube/ingress"
VALUES_FILE="$INGRESS_DIR/values.yaml"

echo "🚀 Installing NGINX Ingress Controller in Minikube..."

# Minikube Ingress Addon ggf. deaktivieren
if minikube addons list | grep -q "ingress: enabled"; then
  echo "⚠️  Minikube Ingress Addon detected — disabling..."
  minikube addons disable ingress
  kubectl delete ns ingress-nginx --ignore-not-found=true
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f "$VALUES_FILE"

echo "✅ Ingress NGINX ready."
