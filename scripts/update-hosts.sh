#!/bin/bash
set -e

# --- Variablen ---
DOMAIN_SUFFIX="minikube.local"
MINIKUBE_IP=$(minikube ip)

echo "🔧 Updating /etc/hosts with Minikube IP: $MINIKUBE_IP"

sudo bash -c "cat <<EOT >> /etc/hosts
$MINIKUBE_IP argocd.$DOMAIN_SUFFIX grafana.$DOMAIN_SUFFIX prometheus.$DOMAIN_SUFFIX alertmanager.$DOMAIN_SUFFIX dashboard.$DOMAIN_SUFFIX
EOT"

echo "✅ /etc/hosts updated successfully."
