#!/bin/bash

set -e

# Configuration
DASHBOARD_TLS_PATH="../../../infrastructure/dashboard/env/local"
ARGOCD_TLS_PATH="../../../infrastructure/argo-cd/env/local"
SEALED_SECRETS_TLS_PATH="../../../infrastructure/sealed-secrets/base"

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

# Fonction pour supprimer des ressources avec Kustomize
delete_kustomize() {
    local path=$1
    local service_name=$2

    if [ ! -d "$path" ]; then
        log_warning "Répertoire Kustomize introuvable: $path"
        return 0
    fi

    log_info "Suppression de $service_name..."

    if kubectl delete -k "$path" --ignore-not-found=true >/dev/null 2>&1; then
        log_success "$service_name supprimé"
    else
        log_warning "Erreur lors de la suppression de $service_name (peut-être déjà supprimé)"
    fi
}

# Fonction pour supprimer un secret
delete_secret() {
    local secret_name=$1
    local namespace=$2

    if namespace_exists "$namespace" && kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        log_info "Suppression du secret $secret_name dans le namespace $namespace..."
        kubectl delete secret "$secret_name" -n "$namespace" --ignore-not-found=true
        log_success "Secret $secret_name supprimé"
    else
        log_info "Secret $secret_name introuvable ou namespace $namespace inexistant"
    fi
}

# Fonction pour supprimer un namespace
delete_namespace() {
    local namespace=$1

    if namespace_exists "$namespace"; then
        log_info "Suppression du namespace $namespace..."
        kubectl delete namespace "$namespace" --ignore-not-found=true --timeout=60s
        log_success "Namespace $namespace supprimé"
    else
        log_info "Namespace $namespace déjà supprimé"
    fi
}

# Fonction pour attendre la suppression d'un namespace
wait_for_namespace_deletion() {
    local namespace=$1
    local timeout=${2:-60}

    if namespace_exists "$namespace"; then
        log_info "Attente de la suppression complète du namespace $namespace..."
        local count=0
        while namespace_exists "$namespace" && [ $count -lt $timeout ]; do
            sleep 1
            ((count++))
        done

        if namespace_exists "$namespace"; then
            log_warning "Timeout lors de la suppression du namespace $namespace"
        else
            log_success "Namespace $namespace complètement supprimé"
        fi
    fi
}

# Fonction pour supprimer les CRDs
delete_crds() {
    log_info "Suppression des Custom Resource Definitions..."

    # Sealed Secrets CRDs
    kubectl delete crd sealedsecrets.bitnami.com --ignore-not-found=true

    # Argo CD CRDs (si elles existent)
    kubectl delete crd applications.argoproj.io --ignore-not-found=true
    kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true
    kubectl delete crd appprojects.argoproj.io --ignore-not-found=true

    log_success "CRDs supprimées"
}

# Fonction pour supprimer les ClusterRoles et ClusterRoleBindings
delete_cluster_resources() {
    log_info "Suppression des ressources cluster (ClusterRoles, ClusterRoleBindings)..."

    # Sealed Secrets
    kubectl delete clusterrole secrets-unsealer --ignore-not-found=true
    kubectl delete clusterrolebinding sealed-secrets-controller --ignore-not-found=true

    # Argo CD (ressources communes)
    kubectl delete clusterrole argocd-application-controller --ignore-not-found=true
    kubectl delete clusterrole argocd-server --ignore-not-found=true
    kubectl delete clusterrolebinding argocd-application-controller --ignore-not-found=true
    kubectl delete clusterrolebinding argocd-server --ignore-not-found=true

    # NGINX Ingress
    kubectl delete clusterrole ingress-nginx --ignore-not-found=true
    kubectl delete clusterrole ingress-nginx-admission --ignore-not-found=true
    kubectl delete clusterrolebinding ingress-nginx --ignore-not-found=true
    kubectl delete clusterrolebinding ingress-nginx-admission --ignore-not-found=true

    # Dashboard
    kubectl delete clusterrole kubernetes-dashboard --ignore-not-found=true
    kubectl delete clusterrolebinding kubernetes-dashboard --ignore-not-found=true
    kubectl delete clusterrole system:kubernetes-dashboard --ignore-not-found=true
    kubectl delete clusterrolebinding system:kubernetes-dashboard --ignore-not-found=true

    log_success "Ressources cluster supprimées"
}

# Fonction pour nettoyer les fichiers locaux
cleanup_local_files() {
    log_info "Nettoyage des fichiers locaux générés..."

    # Supprimer les tokens et mots de passe
    [ -f "$DASHBOARD_TLS_PATH/token.txt" ] && rm -f "$DASHBOARD_TLS_PATH/token.txt" && log_success "Token Dashboard supprimé"
    [ -f "$ARGOCD_TLS_PATH/admin-password.txt" ] && rm -f "$ARGOCD_TLS_PATH/admin-password.txt" && log_success "Mot de passe Argo CD supprimé"

    # Optionnel : supprimer les certificats générés pour Dashboard et Argo CD (décommentez si nécessaire)
    # log_warning "Certificats TLS Dashboard et Argo CD conservés (supprimez manuellement si nécessaire)"
    # rm -f "$DASHBOARD_TLS_PATH/tls.crt" "$DASHBOARD_TLS_PATH/tls.key"
    # rm -f "$ARGOCD_TLS_PATH/tls.crt" "$ARGOCD_TLS_PATH/tls.key"

    # IMPORTANT: Ne jamais supprimer les certificats Sealed Secrets (nécessaires pour le déchiffrement)
    log_info "Certificats Sealed Secrets conservés (requis pour déchiffrer les secrets existants)"
}

# Fonction de confirmation
confirm_uninstall() {
    echo ""
    log_warning "🚨 ATTENTION: Cette opération va supprimer TOUS les composants installés:"
    echo "  • Argo CD (namespace argocd)"
    echo "  • Kubernetes Dashboard (namespace kubernetes-dashboard)"
    echo "  • NGINX Ingress Controller (namespace ingress-nginx)"
    echo "  • Sealed Secrets Controller (namespace kube-system)"
    echo "  • Tous les secrets TLS associés"
    echo "  • Toutes les ressources cluster (CRDs, ClusterRoles, etc.)"
    echo ""

    read -p "Êtes-vous sûr de vouloir continuer? (tapez 'YES' pour confirmer): " confirmation

    if [ "$confirmation" != "YES" ]; then
        log_info "Désinstallation annulée par l'utilisateur"
        exit 0
    fi
}

# Début du script principal
echo "🗑️  Démarrage de la désinstallation de l'infrastructure locale"

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

# Demander confirmation
confirm_uninstall

log_info "=== DÉBUT DE LA DÉSINSTALLATION ==="

# 1. Suppression d'Argo CD
log_info "=== SUPPRESSION D'ARGO CD ==="
delete_kustomize "../../../infrastructure/argo-cd/env/local" "Argo CD"
delete_secret "argocd-tls" "argocd"
delete_namespace "argocd"
wait_for_namespace_deletion "argocd" 120

# 2. Suppression du Kubernetes Dashboard
log_info "=== SUPPRESSION DU KUBERNETES DASHBOARD ==="
delete_kustomize "../../../infrastructure/dashboard/env/local" "Kubernetes Dashboard"
delete_secret "dashboard-tls" "kubernetes-dashboard"
delete_namespace "kubernetes-dashboard"
wait_for_namespace_deletion "kubernetes-dashboard" 60

# 3. Suppression de NGINX Ingress Controller
log_info "=== SUPPRESSION DE NGINX INGRESS CONTROLLER ==="
delete_kustomize "../../../infrastructure/nginx/env/local" "NGINX Ingress Controller"
delete_namespace "ingress-nginx"
wait_for_namespace_deletion "ingress-nginx" 120

# 4. Suppression de Sealed Secrets
log_info "=== SUPPRESSION DE SEALED SECRETS ==="
delete_kustomize "../../../infrastructure/sealed-secrets/env/local" "Sealed Secrets"
delete_secret "sealed-secrets-key" "kube-system"

# 5. Suppression des ressources cluster
log_info "=== SUPPRESSION DES RESSOURCES CLUSTER ==="
delete_cluster_resources

# 6. Suppression des CRDs
log_info "=== SUPPRESSION DES CUSTOM RESOURCE DEFINITIONS ==="
delete_crds

# 7. Nettoyage des fichiers locaux
log_info "=== NETTOYAGE DES FICHIERS LOCAUX ==="
cleanup_local_files

# 8. Vérifications finales
log_info "=== VÉRIFICATIONS FINALES ==="

# Vérifier les namespaces restants
log_info "Vérification des namespaces supprimés..."
for ns in argocd kubernetes-dashboard ingress-nginx; do
    if namespace_exists "$ns"; then
        log_warning "Namespace $ns encore présent (suppression en cours ou bloquée)"
    else
        log_success "Namespace $ns supprimé avec succès"
    fi
done

# Vérifier les CRDs restantes
log_info "Vérification des CRDs supprimées..."
remaining_crds=$(kubectl get crd -o name 2>/dev/null | grep -E "(sealed|argo|ingress)" || true)
if [ -n "$remaining_crds" ]; then
    log_warning "CRDs encore présentes:"
    echo "$remaining_crds"
else
    log_success "Toutes les CRDs supprimées"
fi

# Résumé final
log_success "=== DÉSINSTALLATION TERMINÉE ==="
echo ""
log_info "Composants supprimés:"
echo "  • Argo CD et namespace argocd"
echo "  • Kubernetes Dashboard et namespace kubernetes-dashboard"
echo "  • NGINX Ingress Controller et namespace ingress-nginx"
echo "  • Sealed Secrets Controller (dans kube-system)"
echo "  • Tous les secrets TLS associés"
echo "  • Ressources cluster (CRDs, ClusterRoles, ClusterRoleBindings)"
echo "  • Fichiers de tokens/mots de passe"
echo ""
log_info "Notes importantes:"
echo "  • Les certificats TLS Dashboard et Argo CD ont été conservés pour une réinstallation future"
echo "  • Les certificats Sealed Secrets sont TOUJOURS conservés (requis pour déchiffrer les secrets existants)"
echo "  • Le namespace kube-system n'a pas été supprimé (namespace système)"
echo "  • Vérifiez qu'aucune ressource n'est bloquée en état 'Terminating'"
echo ""
log_info "Commandes utiles pour vérifier:"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl get crd"
echo "  kubectl get clusterroles | grep -E '(sealed|argo|ingress|dashboard)'"
echo "  kubectl get clusterrolebindings | grep -E '(sealed|argo|ingress|dashboard)'"
echo ""
log_success "🎉 Désinstallation complète !"