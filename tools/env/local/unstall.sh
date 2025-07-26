#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Suppression d'Argo CD (overlay local)..."
kubectl delete -k "$SCRIPT_DIR/../../../infrastructure/argo-cd/env/local" || true

# Suppression du secret TLS d'Argo CD
echo "Suppression du secret TLS pour Argo CD..."
kubectl delete secret argocd-tls -n argocd || true

# Suppression des fichiers TLS d'Argo CD
ARGOCD_TLS_PATH="$SCRIPT_DIR/../../../infrastructure/argo-cd/env/local"
rm -f "$ARGOCD_TLS_PATH/tls.crt" "$ARGOCD_TLS_PATH/tls.key" || true

# Suppression du dashboard

echo "Suppression du Kubernetes Dashboard (overlay local)..."
kubectl delete -k "$SCRIPT_DIR/../../../infrastructure/dashboard/env/local" || true

# Suppression du secret TLS du dashboard
echo "Suppression du secret TLS pour le dashboard..."
kubectl delete secret dashboard-tls -n kube-system || true

# Suppression des fichiers TLS et du token du dashboard
DASHBOARD_TLS_PATH="$SCRIPT_DIR/../../../infrastructure/dashboard/env/local"
rm -f "$DASHBOARD_TLS_PATH/tls.crt" "$DASHBOARD_TLS_PATH/tls.key" "$DASHBOARD_TLS_PATH/token.txt" || true

# Suppression de NGINX Ingress Controller
echo "Suppression de NGINX Ingress Controller (overlay local)..."
kubectl delete -k "$SCRIPT_DIR/../../../infrastructure/nginx/env/local" || true

# Suppression de Sealed Secrets
echo "Suppression de Sealed Secrets (overlay local)..."
kubectl delete -k "$SCRIPT_DIR/../../../infrastructure/sealed-secrets/env/local" || true

echo "Désinstallation terminée."