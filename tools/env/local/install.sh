#!/bin/bash

set -e

# Génération des certificats TLS pour le dashboard
DASHBOARD_TLS_PATH="../../../infrastructure/dashboard/env/local"
if [ ! -f "$DASHBOARD_TLS_PATH/tls.crt" ] || [ ! -f "$DASHBOARD_TLS_PATH/tls.key" ]; then
  echo "Génération des certificats TLS pour le dashboard..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$DASHBOARD_TLS_PATH/tls.key" -out "$DASHBOARD_TLS_PATH/tls.crt" \
    -config "$DASHBOARD_TLS_PATH/openssl.cnf" -extensions req_ext
fi

# Génération des certificats TLS pour Argo CD
ARGOCD_TLS_PATH="../../../infrastructure/argo-cd/env/local"
if [ ! -f "$ARGOCD_TLS_PATH/tls.crt" ] || [ ! -f "$ARGOCD_TLS_PATH/tls.key" ]; then
  echo "Génération des certificats TLS pour Argo CD..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$ARGOCD_TLS_PATH/tls.key" -out "$ARGOCD_TLS_PATH/tls.crt" \
    -config "$ARGOCD_TLS_PATH/openssl.cnf" -extensions req_ext
fi

echo "Déploiement de NGINX Ingress Controller (overlay local)..."
kubectl apply -k "../../../infrastructure/nginx/env/local"
echo "Attente que le pod ingress-nginx-controller soit prêt..."
kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=120s
echo "Le contrôleur NGINX Ingress est prêt."
echo "Attente du démarrage de l'Ingress Controller (10s)..."
sleep 5

echo "Déploiement du Kubernetes Dashboard (overlay local)..."
kubectl apply -k "../../../infrastructure/dashboard/env/local"
echo "Attente du démarrage du Dashboard (10s)..."
sleep 5

# Création du secret TLS pour le dashboard (après création du namespace)
kubectl create secret tls dashboard-tls \
  --cert="$DASHBOARD_TLS_PATH/tls.crt" --key="$DASHBOARD_TLS_PATH/tls.key" \
  -n kube-system --dry-run=client -o yaml | kubectl apply -f -

# Génération du token admin-user pour le dashboard et stockage dans token.txt
DASHBOARD_TOKEN_PATH="$DASHBOARD_TLS_PATH/token.txt"
echo "Génération du token d'accès admin-user pour le dashboard..."
kubectl -n kubernetes-dashboard create token admin-user > "$DASHBOARD_TOKEN_PATH"
echo "Token stocké dans $DASHBOARD_TOKEN_PATH"

echo "Déploiement d'Argo CD (overlay local)..."
kubectl apply -k "../../../infrastructure/argo-cd/env/local"
echo "Attente du démarrage d'Argo CD (10s)..."
sleep 5

# Création du secret TLS pour Argo CD (après création du namespace)
kubectl create secret tls argocd-tls \
  --cert="$ARGOCD_TLS_PATH/tls.crt" --key="$ARGOCD_TLS_PATH/tls.key" \
  -n argocd --dry-run=client -o yaml | kubectl apply -f -

echo "Déploiement de Sealed Secrets (overlay local)..."
kubectl apply -k "../../../infrastructure/sealed-secrets/env/local"
echo "Attente du démarrage de Sealed Secrets (10s)..."
sleep 5

echo "Installation terminée."