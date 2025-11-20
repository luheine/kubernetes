#!/usr/bin/env bash

# ============================================================================
# Homer Sport Website – Setup Script
# Integration into existing ArgoCD Root App‑of‑Apps
# ============================================================================
# Dieses Skript:
# 1. Erstellt die Verzeichnisstruktur für Homer als App
# 2. Erzeugt eine ArgoCD Application YAML
# 3. Optional: erzeugt eine values.yaml + Kustomize-Basis
# 4. Aktualisiert das bestehende Root-App Manifest (falls auto-merge gewünscht)
# ============================================================================

# -----------------------------
# Variablen
# -----------------------------
ROOT_DIR="clusters/minikube/apps"              # Basisverzeichnis der Apps
APP_NAME="sportweb"
APP_DIR="$ROOT_DIR/$APP_NAME"
GIT_REPO="https://github.com/luheine/kubernetes.git"   # Dein Repo
NAMESPACE="sportweb"
ARGO_ROOT_FILE="/home/ansible/kubernetes/roles/argocd/templates/root-application.yaml"
HOMER_IMAGE="b4bz/homer:latest"

# -----------------------------
# Ordnerstruktur anlegen
# -----------------------------
echo "📁 Erstelle App-Verzeichnis: $APP_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/chart" "$APP_DIR/config"

# -----------------------------
# values.yaml für Homer erzeugen
# -----------------------------
cat > "$APP_DIR/values.yaml" <<EOF
image:
  repository: $HOMER_IMAGE
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: sport.example.com
      paths:
        - path: /
          pathType: Prefix
EOF

echo "✔️ values.yaml erstellt"

# -----------------------------
# ArgoCD Application für Homer erzeugen
# -----------------------------
cat > "$APP_DIR/application.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $GIT_REPO
    targetRevision: HEAD
    path: $APP_DIR
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "✔️ ArgoCD Application erzeugt: $APP_DIR/application.yaml"

# -----------------------------
# Namespace YAML erzeugen
# -----------------------------
cat > "$APP_DIR/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF

# -----------------------------
# Root App-of-Apps aktualisieren
# -----------------------------
if grep -q "- name: $APP_NAME" "$ARGO_ROOT_FILE"; then
  echo "🔄 Root-App enthält bereits einen Eintrag für $APP_NAME — überspringe"
else
  echo "➕ Füge App-of-Apps Eintrag hinzu"
  sed -i "/applications:/a \\  - name: $APP_NAME\\n    path: $APP_DIR" "$ARGO_ROOT_FILE"
fi

# -----------------------------
# Fertig
# -----------------------------
echo "🎉 Setup abgeschlossen! Homer-App ist nun bereit für ArgoCD."

