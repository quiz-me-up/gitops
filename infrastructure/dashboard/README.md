# Installation du Kubernetes Dashboard

Ce dossier contient le manifeste pour installer le Kubernetes Dashboard sur votre cluster Kubernetes avec l'option de skip login.

## Prérequis
- Un cluster Kubernetes opérationnel
- `kubectl` configuré pour accéder au cluster
- Un Ingress Controller (ex : NGINX) si vous souhaitez exposer l'interface web

## Installation
1. **Déployer le dashboard**
2. 
   ```bash
    kubectl apply -fhttps://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
   ```
 ou
   ```bash
   kubectl apply -f deployment.yaml
   ```

2. **Vérifier le déploiement**
   ```bash
   kubectl get pods -n kubernetes-dashboard
   kubectl get svc -n kubernetes-dashboard
   ```

3. **Accéder à l'interface web**
   - L'interface est exposée via l'Ingress à l'adresse : https://dashboard.quizmeup.local
   - Configurez votre DNS ou `/etc/hosts` pour pointer ce domaine vers l'IP de votre Ingress Controller.


4. **Créer le certificat TLS pour l'Ingress**
   - Assurez-vous que le certificat TLS est configuré pour l'Ingress du dashboard. Vous pouvez utiliser un certificat auto-signé ou Let's Encrypt.
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout tls.key -out tls.crt \
      -config openssl.cnf -extensions req_ext
   ```
   ```bash
   kubectl create secret tls dashboard-tls \
      --cert=tls.crt \
      --key=tls.key \
      -n kubernetes-dashboard
      ```

## Accès avec un token
Pour accéder au dashboard avec un token d'accès, créez un utilisateur admin et récupérez le token :

1. **Créer un compte admin**
   ```bash
   kubectl apply -f admin-user.yaml
   ```

2. **Récupérer le token d'accès**
   ```bash
   kubectl -n kubernetes-dashboard create token admin-user
   ```

3. **Utiliser le token**
   - Connectez-vous au dashboard avec le token affiché.

## Désinstallation
1. **Supprimer le dashboard**
   ```bash
   kubectl delete -f deployment.yaml
   ```

## Documentation officielle
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)

## Remarques
- L'option `--enable-skip-login` permet d'accéder au dashboard sans authentification.
- Pour plus de sécurité, il est recommandé de désactiver cette option en production.
