#!/bin/bash

set -e

# Configuration
DASHBOARD_TLS_PATH="../../infrastructure/dashboard/env/local"
ARGOCD_TLS_PATH="../../infrastructure/argo-cd/env/local"
SEALED_SECRETS_TLS_PATH="../../infrastructure/sealed-secrets/base"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour les logs colorés
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour vérifier si un namespace existe
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Fonction pour attendre qu'un déploiement soit prêt
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-120}

    log_info "Attente que le déploiement $deployment soit prêt dans le namespace $namespace..."
    if kubectl wait --for=condition=Available deployment/$deployment -n $namespace --timeout=${timeout}s >/dev/null 2>&1; then
        log_success "Déploiement $deployment prêt"
    else
        log_warning "Timeout lors de l'attente du déploiement $deployment"
    fi
}

# Fonction pour générer des certificats TLS
generate_tls_cert() {
    local path=$1
    local service_name=$2

    if [ ! -f "$path/tls.crt" ] || [ ! -f "$path/tls.key" ]; then
        log_info "Génération des certificats TLS pour $service_name..."

        # Vérifier que le fichier de config OpenSSL existe
        if [ ! -f "$path/openssl.cnf" ]; then
            log_error "Fichier de configuration OpenSSL manquant: $path/openssl.cnf"
            return 1
        fi

        # Créer le répertoire si nécessaire
        mkdir -p "$path"

        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$path/tls.key" -out "$path/tls.crt" \
            -config "$path/openssl.cnf" -extensions req_ext

        log_success "Certificats TLS générés pour $service_name"
    else
        log_info "Certificats TLS existants pour $service_name"
    fi
}

# Fonction pour créer un secret TLS
create_tls_secret() {
    local secret_name=$1
    local cert_path=$2
    local key_path=$3
    local namespace=$4

    log_info "Création/mise à jour du secret TLS $secret_name dans le namespace $namespace..."

    kubectl create secret tls "$secret_name" \
        --cert="$cert_path" --key="$key_path" \
        -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    log_success "Secret TLS $secret_name créé/mis à jour"
}

# Fonction pour appliquer des manifestes Kustomize
apply_kustomize() {
    local path=$1
    local service_name=$2

    log_info "Déploiement de $service_name..."

    if [ ! -d "$path" ]; then
        log_error "Répertoire Kustomize introuvable: $path"
        return 1
    fi

    kubectl apply -k "$path"
    log_success "$service_name déployé"
}

# Début du script principal
echo "🚀 Démarrage du déploiement de l'infrastructure locale"

# Vérifier que kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl n'est pas installé ou n'est pas dans le PATH"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Impossible de se connecter au cluster Kubernetes"
    exit 1
fi

log_success "Connexion au cluster Kubernetes établie"

# 1. Génération des certificats TLS
log_info "=== GÉNÉRATION DES CERTIFICATS TLS ==="
generate_tls_cert "$DASHBOARD_TLS_PATH" "Dashboard"
generate_tls_cert "$ARGOCD_TLS_PATH" "Argo CD"
generate_tls_cert "$SEALED_SECRETS_TLS_PATH" "Sealed Secrets"

# 2. Déploiement de Sealed Secrets
log_info "=== DÉPLOIEMENT DE SEALED SECRETS ==="
create_tls_secret "sealed-secrets-key" "$SEALED_SECRETS_TLS_PATH/tls.crt" "$SEALED_SECRETS_TLS_PATH/tls.key" "kube-system"
apply_kustomize "../../infrastructure/sealed-secrets/env/local" "Sealed Secrets"
wait_for_deployment "kube-system" "sealed-secrets-controller" 120

# 3. Déploiement de NGINX Ingress Controller
log_info "=== DÉPLOIEMENT DE NGINX INGRESS CONTROLLER ==="
apply_kustomize "../../infrastructure/nginx/env/local" "NGINX Ingress Controller"

# Attendre que le namespace ingress-nginx soit créé
log_info "Attente de la création du namespace ingress-nginx..."
timeout=30
while [ $timeout -gt 0 ] && ! namespace_exists "ingress-nginx"; do
    sleep 1
    ((timeout--))
done

if namespace_exists "ingress-nginx"; then
    log_info "Attente que le contrôleur NGINX Ingress soit prêt..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=Ready pod -l app.kubernetes.io/component=controller \
        --timeout=120s
    log_success "Contrôleur NGINX Ingress prêt"
else
    log_warning "Namespace ingress-nginx non créé dans les temps"
fi

# 4. Déploiement du Kubernetes Dashboard
log_info "=== DÉPLOIEMENT DU KUBERNETES DASHBOARD ==="
apply_kustomize "../../infrastructure/dashboard/env/local" "Kubernetes Dashboard"

# Attendre que le namespace soit créé avant de créer le secret
log_info "Attente de la création du namespace kubernetes-dashboard..."
timeout=30
while [ $timeout -gt 0 ] && ! namespace_exists "kubernetes-dashboard"; do
    sleep 1
    ((timeout--))
done

if namespace_exists "kubernetes-dashboard"; then
    create_tls_secret "dashboard-tls" "$DASHBOARD_TLS_PATH/tls.crt" "$DASHBOARD_TLS_PATH/tls.key" "kubernetes-dashboard"
    wait_for_deployment "kubernetes-dashboard" "kubernetes-dashboard" 120

    # Génération du token admin-user
    log_info "Génération du token d'accès admin-user pour le dashboard..."
    DASHBOARD_TOKEN_PATH="$DASHBOARD_TLS_PATH/token.txt"

    # Attendre que le ServiceAccount soit créé
    timeout=30
    while [ $timeout -gt 0 ] && ! kubectl get serviceaccount admin-user -n kubernetes-dashboard >/dev/null 2>&1; do
        sleep 1
        ((timeout--))
    done

    if kubectl get serviceaccount admin-user -n kubernetes-dashboard >/dev/null 2>&1; then
        kubectl -n kubernetes-dashboard create token admin-user > "$DASHBOARD_TOKEN_PATH"
        log_success "Token stocké dans $DASHBOARD_TOKEN_PATH"
    else
        log_warning "ServiceAccount admin-user non trouvé, token non généré"
    fi
else
    log_warning "Namespace kubernetes-dashboard non créé, secret TLS non créé"
fi

# 5. Déploiement d'Argo CD
log_info "=== DÉPLOIEMENT D'ARGO CD ==="
apply_kustomize "../../infrastructure/argo-cd/env/local" "Argo CD"

# Attendre que le namespace soit créé avant de créer le secret
log_info "Attente de la création du namespace argocd..."
timeout=30
while [ $timeout -gt 0 ] && ! namespace_exists "argocd"; do
    sleep 1
    ((timeout--))
done

if namespace_exists "argocd"; then
    create_tls_secret "argocd-tls" "$ARGOCD_TLS_PATH/tls.crt" "$ARGOCD_TLS_PATH/tls.key" "argocd"
    wait_for_deployment "argocd" "argocd-server" 120

    # Récupération du mot de passe admin d'Argo CD
    log_info "Récupération du mot de passe admin d'Argo CD..."
    timeout=60
    while [ $timeout -gt 0 ] && ! kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; do
        sleep 1
        ((timeout--))
    done

    if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        echo "$ARGOCD_PASSWORD" > "$ARGOCD_TLS_PATH/admin-password.txt"
        log_success "Mot de passe admin Argo CD stocké dans $ARGOCD_TLS_PATH/admin-password.txt"
        log_info "Login Argo CD - Utilisateur: admin, Mot de passe: $ARGOCD_PASSWORD"
    else
        log_warning "Secret argocd-initial-admin-secret non trouvé"
    fi
else
    log_warning "Namespace argocd non créé, secret TLS non créé"
fi

# Résumé final
log_success "=== INSTALLATION TERMINÉE ==="
echo ""
log_info "Services déployés:"
echo "  • Sealed Secrets Controller"
echo "  • NGINX Ingress Controller"
echo "  • Kubernetes Dashboard"
echo "  • Argo CD"
echo ""
log_info "Fichiers générés:"
if [ -f "$DASHBOARD_TOKEN_PATH" ]; then
    echo "  • Token Dashboard: $DASHBOARD_TOKEN_PATH"
fi
if [ -f "$ARGOCD_TLS_PATH/admin-password.txt" ]; then
    echo "  • Mot de passe Argo CD: $ARGOCD_TLS_PATH/admin-password.txt"
fi
echo ""
log_info "Vérifiez le statut des pods avec:"
echo "  kubectl get pods --all-namespaces"