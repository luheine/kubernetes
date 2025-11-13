#!/usr/bin/env bash
#######################################
### notwendige Variablen definieren ###
#######################################
GIT_PROJECT="kubernetes"
PROJECT_DIR="/home/ansible/$GIT_PROJECT"
GITHUB_USER="luheine"


set -e

echo "🚀 Starte Erstellung des Homelab-Projektgerüsts ..."

# Basisverzeichnis
#PROJECT_DIR="$HOME/homelab-minikube-gitops"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "📁 Erstelle Verzeichnisstruktur ..."
mkdir -p \
  clusters/minikube/ingress \
  clusters/minikube/cert-manager \
  clusters/minikube/charts/dashboard/templates \
  clusters/minikube/apps/dashboard \
  playbooks

# --- 1. Ingress Config ---
cat > clusters/minikube/ingress/nginx-ingress-values.yaml <<'EOF'
controller:
  ingressClass: nginx
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
  metrics:
    enabled: true
  watchIngressWithoutClass: true
defaultBackend:
  enabled: true
EOF

cat > clusters/minikube/ingress/install-ingress.sh <<'EOF'
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
EOF
chmod +x clusters/minikube/ingress/install-ingress.sh

# --- 2. Cert-Manager ClusterIssuer ---
cat > clusters/minikube/cert-manager/cluster-issuer-staging.yaml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@minikube.local
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

cat > clusters/minikube/cert-manager/cluster-issuer-prod.yaml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@minikube.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# --- 3. Dashboard Helm Chart ---
cat > clusters/minikube/charts/dashboard/Chart.yaml <<'EOF'
apiVersion: v2
name: dashboard
description: Simple Homelab Startpage
type: application
version: 0.1.0
appVersion: "1.0"
EOF

cat > clusters/minikube/charts/dashboard/values.yaml <<'EOF'
image:
  repository: ghcr.io/bastienwirtz/homer
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: dashboard.minikube.local
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: dashboard-tls
      hosts:
        - dashboard.minikube.local

config:
  title: "🏡 Homelab Dashboard"
  subtitle: "Minikube GitOps Setup"
  links:
    - name: ArgoCD
      url: "https://argocd.minikube.local"
      icon: "fas fa-code-branch"
    - name: Grafana
      url: "https://grafana.minikube.local"
      icon: "fas fa-chart-line"
    - name: Prometheus
      url: "https://prometheus.minikube.local"
      icon: "fas fa-database"
    - name: Alertmanager
      url: "https://alertmanager.minikube.local"
      icon: "fas fa-bell"
    - name: Homepage
      url: "https://homepage.minikube.local"
      icon: "fas fa-home"
EOF

cat > clusters/minikube/charts/dashboard/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dashboard
  template:
    metadata:
      labels:
        app: dashboard
    spec:
      containers:
        - name: homer
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: config
              mountPath: /www/assets/config.yml
              subPath: config.yml
      volumes:
        - name: config
          configMap:
            name: dashboard-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-config
data:
  config.yml: |
    title: {{ .Values.config.title }}
    subtitle: {{ .Values.config.subtitle }}
    links:
    {{- range .Values.config.links }}
      - name: {{ .name }}
        url: {{ .url }}
        icon: {{ .icon }}
    {{- end }}
EOF

cat > clusters/minikube/charts/dashboard/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: dashboard
spec:
  selector:
    app: dashboard
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
EOF

cat > clusters/minikube/charts/dashboard/templates/ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - dashboard.minikube.local
      secretName: dashboard-tls
  rules:
    - host: dashboard.minikube.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: dashboard
                port:
                  number: 8080
EOF

# --- 4. ArgoCD Application ---
cat > clusters/minikube/apps/dashboard/application-dashboard.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dashboard
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/$GITHUB_USER/$GIT_PROJECT.git"
    targetRevision: main
    path: clusters/minikube/charts/dashboard
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# --- 5. Ansible Bootstrap ---
cat > playbooks/bootstrap.yml <<'EOF'
---
- name: Bootstrap complete Minikube Homelab
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    kube_context: minikube
  tasks:

    - name: Ensure Minikube is running
      shell: |
        minikube status | grep "host: Running" || minikube start --driver=docker
      changed_when: false

    - name: Enable Minikube Ingress addon
      shell: minikube addons enable ingress
      changed_when: false

    - name: Deploy NGINX Ingress Controller via Helm
      shell: bash clusters/minikube/ingress/install-ingress.sh
      changed_when: false

    - name: Install cert-manager CRDs
      shell: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
      changed_when: false

    - name: Install cert-manager Helm chart
      shell: |
        helm repo add jetstack https://charts.jetstack.io || true
        helm repo update
        helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true
      changed_when: false

    - name: Apply staging ClusterIssuer
      shell: kubectl apply -f clusters/minikube/cert-manager/cluster-issuer-staging.yaml
      changed_when: false

    - name: Apply production ClusterIssuer
      shell: kubectl apply -f clusters/minikube/cert-manager/cluster-issuer-prod.yaml
      changed_when: false

    - name: Install ArgoCD via Helm
      shell: |
        helm repo add argo https://argoproj.github.io/argo-helm || true
        helm repo update
        helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace
      changed_when: false

    - name: Deploy Root ArgoCD App-of-Apps
      shell: kubectl apply -f clusters/minikube/apps/root-application.yaml -n argocd
      changed_when: false

    - name: Update /etc/hosts for Minikube domains
      become: yes
      lineinfile:
        path: /etc/hosts
        line: "{{ item }}"
        state: present
      loop:
        - "{{ lookup('pipe','minikube ip') }} argocd.minikube.local homepage.minikube.local grafana.minikube.local prometheus.minikube.local alertmanager.minikube.local dashboard.minikube.local"

    - name: Wait for all pods in default namespace to be running
      shell: kubectl wait --for=condition=Ready pods --all --namespace default --timeout=300s
      changed_when: false
EOF

echo "✅ Projektstruktur erstellt unter: $PROJECT_DIR"
echo "💡 Jetzt kannst du dein Repo initialisieren:"
echo ""
echo "  cd $PROJECT_DIR"
echo "  git init && git add . && git commit -m 'Initial Homelab setup'"
echo "  git remote add origin https://github.com/<dein-github-user>/homelab-minikube-gitops.git"
echo "  git push -u origin main"
echo ""
echo "🚀 Danach kannst du mit 'ansible-playbook playbooks/bootstrap.yml' dein Homelab starten!"

