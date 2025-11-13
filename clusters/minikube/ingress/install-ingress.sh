#!/usr/bin/env bash
set -e

echo "🚀 Installing NGINX Ingress Controller in Minikube..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f clusters/minikube/ingress/nginx-ingress-values.yaml

kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
echo "✅ NGINX Ingress Controller deployed!"
