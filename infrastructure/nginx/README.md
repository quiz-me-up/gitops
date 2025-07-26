# Installation du contrôleur NGINX Ingress

Ce dossier contient le manifeste pour installer le contrôleur NGINX Ingress sur un cluster Kubernetes.

## Prérequis
- Un cluster Kubernetes opérationnel
- `kubectl` configuré pour accéder au cluster

## Installation
1. **Installer le contrôleur NGINX Ingress (méthode locale)**
   ```bash
   kubectl apply -f nginx-ingress.yaml
   ```

2. **Désinstaller le contrôleur NGINX Ingress**
   ```bash
   kubectl delete -f nginx-ingress.yaml
   ```

3. **Vérifier le déploiement**
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get svc -n ingress-nginx
   ```

4. **Accès**
   - Le service `ingress-nginx-controller` est exposé en LoadBalancer sur les ports 80 (HTTP) et 443 (HTTPS).
   - Utilisez l'adresse IP du service pour configurer vos DNS ou `/etc/hosts`.

## Documentation officielle
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

## Remarques
- Vous pouvez personnaliser le manifeste selon vos besoins (ressources, annotations, etc.).
- Ce contrôleur est nécessaire pour exposer les applications via des ressources Ingress (ex : Argo CD, microservices).
