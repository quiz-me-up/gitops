# Installation d'Argo CD sur Kubernetes

Ce dossier contient les manifestes nécessaires pour installer Argo CD sur un cluster Kubernetes.

## Prérequis
- Un cluster Kubernetes opérationnel
- `kubectl` configuré pour accéder au cluster
- Un Ingress Controller (ex : NGINX) si vous souhaitez exposer l'interface web

**Créer le certificat TLS pour l'Ingress**
   - Assurez-vous que le certificat TLS est configuré pour l'Ingress du dashboard. Vous pouvez utiliser un certificat auto-signé ou Let's Encrypt.
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout tls.key -out tls.crt \
      -config openssl.cnf -extensions req_ext
   ```
   ```bash
   kubectl create secret tls argocd-tls \
      --cert=tls.crt \
      --key=tls.key \
      -n argocd
   ```

## Installation
1. **Créer le namespace et les ressources Argo CD**
   ```bash
   kubectl apply -n argocd -f deployment.yaml 
   // 
   kubectl apply -k . overlays/local
   ```

2. **Désinstaller Argo CD**
   ```bash
   kubectl delete -f deployment.yaml
   ```

3. **Vérifier le déploiement**
   ```bash
   kubectl get pods -n argocd
   kubectl get svc -n argocd
   ```

4. **Accéder à l'interface web**
   - L'interface est exposée via l'Ingress à l'adresse : http://argocd.quizmeup.local
   - Configurez votre DNS ou `/etc/hosts` pour pointer ce domaine vers l'IP de votre Ingress Controller.

5. **Récupérer le mot de passe initial**
   ```bash
   kubectl -n argocd get secret argocd-server -o jsonpath="{.data.password}" | base64 -d
   ```
   - Identifiant : `admin`
   - Mot de passe : valeur récupérée ci-dessus

## Documentation officielle
- [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)

## Remarques
- Pour personnaliser l'installation, modifiez le fichier `install.yaml`.
- Pour connecter Argo CD à votre repository GitOps, ajoutez une ressource `Application` Argo CD.
