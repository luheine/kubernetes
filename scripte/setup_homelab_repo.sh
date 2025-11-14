#!/bin/bash
set -e

########################################
# 🏗️  Pfad-Definitionen
########################################
PROJECT_DIR="$HOME/kubernetes"
CLUSTERS_DIR="$PROJECT_DIR/clusters/minikube"
INGRESS_DIR="$CLUSTERS_DIR/ingress"
CERT_DIR="$CLUSTERS_DIR/cert-manager"
APPS_DIR="$CLUSTERS_DIR/apps"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
PLAYBOOKS_DIR="$PROJECT_DIR/playbooks"

########################################
# 📁 Verzeichnisstruktur erstellen
########################################
echo "📁 Erstelle Projektstruktur unter: $PROJECT_DIR"
mkdir -p \
  "$INGRESS_DIR" \
  "$CERT_DIR" \
  "$APPS_DIR/dashboard" \
  "$SCRIPTS_DIR" \
  "$PLAYBOOKS_DIR"

########################################
# ⚙️  Helm values.yaml für Ingress erstellen
########################################
cat <<'EOF' > "$INGRESS_DIR/values.yaml"
controller:
  replicaCount: 1
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
  admissionWebhooks:
    enabled: false
  metrics:
    enabled: true
  config:
    use-forwarded-headers: "true"
    enable-real-ip: "true"
    compute-full-forwarded-for: "true"
    proxy-body-size: "64m"
    proxy-read-timeout: "600"
    proxy-send-timeout: "600"
  extraArgs:
    default-ssl-certificate: "cert-manager/tls-secret"
EOF

########################################
# 🧰 install-ingress.sh
########################################
cat <<'EOF' > "$INGRESS_DIR/install-ingress.sh"
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
EOF
chmod +x "$INGRESS_DIR/install-ingress.sh"

########################################
# 🧰 install-cert-manager.sh
########################################
cat <<'EOF' > "$SCRIPTS_DIR/install-cert-manager.sh"
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
EOF
chmod +x "$SCRIPTS_DIR/install-cert-manager.sh"

########################################
# 🧰 install-argocd.sh
########################################
cat <<'EOF' > "$SCRIPTS_DIR/install-argocd.sh"
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
EOF
chmod +x "$SCRIPTS_DIR/install-argocd.sh"

########################################
# 🧰 update-hosts.sh
########################################
cat <<'EOF' > "$SCRIPTS_DIR/update-hosts.sh"
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
EOF
chmod +x "$SCRIPTS_DIR/update-hosts.sh"

########################################
# 📜 Bootstrap Playbook
########################################
cat <<EOF > "$PLAYBOOKS_DIR/bootstrap.yml"
---
- name: Bootstrap complete Minikube Homelab
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    project_dir: "$PROJECT_DIR"
  tasks:
    - name: Ensure Minikube is running
      shell: |
        minikube status | grep "host: Running" || minikube start --driver=podman
      changed_when: false

    - name: Deploy NGINX Ingress Controller via Helm
      shell: bash "$INGRESS_DIR/install-ingress.sh"
      changed_when: false

    - name: Install cert-manager via Helm
      shell: bash "$SCRIPTS_DIR/install-cert-manager.sh"
      changed_when: false

    - name: Install ArgoCD via Helm
      shell: bash "$SCRIPTS_DIR/install-argocd.sh"
      changed_when: false

    - name: Update /etc/hosts entries
      shell: bash "$SCRIPTS_DIR/update-hosts.sh"
      changed_when: false

    - name: Wait for all pods to be ready
      shell: kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s
      changed_when: false
EOF

########################################
# 🧭 Git-Setup
########################################
cd "$PROJECT_DIR"
git init -q
git add .
git commit -m "Initial Homelab Minikube GitOps setup" -q

echo "✅ Setup abgeschlossen!"
echo "💡 Starte dein Homelab mit:"
echo "ansible-playbook playbooks/bootstrap.yml"
