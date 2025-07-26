# Sealed Secrets

Ce dossier contient la configuration Kubernetes pour l'installation et la gestion de Sealed Secrets.

## Installation locale

1. Appliquer la configuration de base :
   ```sh
   kubectl apply -k base/
   ```
2. Appliquer la configuration d'environnement local :
   ```sh
   kubectl apply -k env/local/
   ```

## Installation en production

1. Appliquer la configuration de base :
   ```sh
   kubectl apply -k base/
   ```
2. Appliquer la configuration d'environnement production :
   ```sh
   kubectl apply -k env/production/
   ```

## Désinstallation

Pour supprimer Sealed Secrets :

- En local :
  ```sh
  kubectl delete -k env/local/
  kubectl delete -k base/
  ```
- En production :
  ```sh
  kubectl delete -k env/production/
  kubectl delete -k base/
  ```

## Références
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)


