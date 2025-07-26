#!/bin/bash

set -e

# Installation des CRDs de cert-manager
# (obligatoire avant le déploiement de cert-manager)
echo "Installation des CRDs de cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml

# Installation de cert-manager
# (déploiement via Kustomize)
echo "Installation de cert-manager..."
kubectl apply -k ../infrastructure/cert-manager/env/development
kubectl wait --namespace cert-manager --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager --timeout=120s

# Déploiement de NGINX Ingress Controller (overlay development)..."
kubectl apply -k ../infrastructure/nginx/env/development
echo "Attente que le pod ingress-nginx-controller soit prêt..."
kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s
echo "Le contrôleur NGINX Ingress est prêt."
echo "Attente du démarrage de l'Ingress Controller (10s)..."
sleep 5

echo "Déploiement du Kubernetes Dashboard (overlay development)..."
kubectl apply -k ../infrastructure/dashboard/env/development
echo "Attente du démarrage du Dashboard (10s)..."
sleep 5

# Déploiement d'Argo CD (overlay development, cert-manager gère le TLS)
kubectl apply -k ../infrastructure/argo-cd/env/development
echo "Attente du démarrage du argo (10s)..."
sleep 5

# Génération du token admin-user pour le dashboard et stockage dans token.txt
DASHBOARD_TOKEN_PATH="../infrastructure/dashboard/env/development/token.txt"
echo "Génération du token d'accès admin-user pour le dashboard..."
kubectl -n kubernetes-dashboard create token admin-user > "$DASHBOARD_TOKEN_PATH"
echo "Token stocké dans $DASHBOARD_TOKEN_PATH"

echo "Déploiement de Sealed Secrets (overlay development)..."
kubectl apply -k ../infrastructure/sealed-secrets/env/development
echo "Attente du démarrage de Sealed Secrets (10s)..."
sleep 5

echo "Installation terminée."
