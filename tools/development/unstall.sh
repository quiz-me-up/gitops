#!/bin/bash

set -e

# Suppression des CRDs de cert-manager
echo "Suppression des CRDs de cert-manager..."
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml || true

echo "Suppression d'Argo CD (overlay development)..."
kubectl delete -k ../infrastructure/argo-cd/env/development || true

# Suppression du secret TLS d'Argo CD (géré par cert-manager)
echo "Suppression du secret TLS pour Argo CD..."
kubectl delete secret argocd-tls -n argocd || true

# Suppression du dashboard

echo "Suppression du Kubernetes Dashboard (overlay development)..."
kubectl delete -k ../infrastructure/dashboard/env/development || true

# Suppression du secret TLS du dashboard (géré par cert-manager)
echo "Suppression du secret TLS pour le dashboard..."
kubectl delete secret dashboard-tls -n kube-system || true

# Suppression du token du dashboard
echo "Suppression du token admin-user du dashboard..."
DASHBOARD_TOKEN_PATH="../infrastructure/dashboard/env/development/token.txt"
rm -f "$DASHBOARD_TOKEN_PATH" || true

# Suppression de Sealed Secrets
echo "Suppression de Sealed Secrets (overlay development)..."
kubectl delete -k ../infrastructure/sealed-secrets/env/development || true

# Suppression de cert-manager et du ClusterIssuer
echo "Suppression de cert-manager et du ClusterIssuer..."
kubectl delete -k ../infrastructure/cert-manager/env/development || true

# Suppression de NGINX Ingress Controller
echo "Suppression de NGINX Ingress Controller (overlay development)..."
kubectl delete -k ../infrastructure/nginx/env/development || true

echo "Désinstallation terminée."
