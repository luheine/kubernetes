#!/bin/bash

# --- Pfade ---
WSL_KUBECONFIG="/home/ansible/.kube/config"
WSL_CA_CRT="/home/ansible/.minikube/ca.crt"
WSL_CRT="/home/ansible/.minikube/profiles/minikube/"
WIN_KUBECONFIG="/mnt/c/Users/LG/.kube/config"
WIN_MINIKUBE="C:\\\\Users\\\\LG\\\\.kube\\\\certs"
WIN_PROFILE="C:\\\\Users\\\\LG\\\\.kube\\\\certs"
WIN_KUBECERT="/mnt/c/Users/LG/.kube/certs"

# --- Ordner erstellen ---
mkdir -p /mnt/c/Users/LG/.kube

echo "[INFO] Kopiere neue kubeconfig nach Windows…"
cp "$WSL_KUBECONFIG" "$WIN_KUBECONFIG"
echo "[INFO] Kopiere neue Zertifikate nach Windows…"
cp "$WSL_CA_CRT" "$WIN_KUBECERT"
cp -r "$WSL_CRT" "$WIN_KUBECERT"

echo "[INFO] Ersetze Linux-Pfade durch Windows-Pfade…"
sed -i \
  -e "s#/home/ansible/.minikube/profiles/minikube/client.crt#$WIN_PROFILE\\\\client.crt#g" \
  -e "s#/home/ansible/.minikube/profiles/minikube/client.key#$WIN_PROFILE\\\\client.key#g" \
  -e "s#/home/ansible/.minikube/ca.crt#$WIN_MINIKUBE\\\\ca.crt#g" \
  "$WIN_KUBECONFIG"

# optional: Windows-kompatible Zeilenenden
unix2dos "$WIN_KUBECONFIG" 2>/dev/null

echo ""
echo "[OK] Windows kubeconfig aktualisiert!"
echo "     -> $WIN_KUBECONFIG"
echo "Du kannst jetzt unter Windows sofort:"
echo "kubectl get nodes"
echo "und Lens öffnen."

