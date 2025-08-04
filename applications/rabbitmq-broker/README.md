# RabbitMQ Cluster sur Kubernetes avec Auto-Scaling

Ce projet déploie un cluster RabbitMQ haute disponibilité sur Kubernetes avec scaling horizontal automatique (HPA).

## 📋 Prérequis

- Cluster Kubernetes 1.19+
- kubectl configuré
- Metrics Server installé (pour HPA)
- Ingress Controller (nginx recommandé)
- StorageClass configurée (optionnel)

### Vérification des prérequis

```bash
# Vérifier que Metrics Server est installé
kubectl get deployment metrics-server -n kube-system

# Vérifier les StorageClasses disponibles
kubectl get storageclass

# Vérifier l'Ingress Controller
kubectl get pods -n ingress-nginx
```

## 🚀 Installation

### 1. Déployer tous les manifestes

```bash
# Cloner et naviguer vers le répertoire
git clone <votre-repo>
cd rabbitmq-k8s

# Déployer dans l'ordre
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-rabbitmq-broker-config-map.yaml
kubectl apply -f 03-rabbitmq-broker-secret.yaml
kubectl apply -f 04-rabbitmq-broker-rbac.yaml
kubectl apply -f 05-rabbitmq-broker-headless-service.yaml
kubectl apply -f 06-rabbitmq-broker-service.yaml
kubectl apply -f 07-rabbitmq-broker-statefulset.yaml
kubectl apply -f 08-rabbitmq-broker-hpa.yaml
kubectl apply -f 09-rabbitmq-broker-ingress.yaml
kubectl apply -f 10-rabbitmq-broker-networkpolicy.yaml

# Ou déployer tout d'un coup
kubectl apply -f .
```

### 2. Vérifier le déploiement

```bash
# Vérifier les pods
kubectl get pods -n quizmeup -l app=rabbitmq-broker

# Vérifier les services
kubectl get svc -n quizmeup

# Vérifier le HPA
kubectl get hpa -n quizmeup

# Vérifier le cluster RabbitMQ
kubectl exec -it rabbitmq-broker-0 -n quizmeup -- rabbitmq-diagnostics cluster_status
```

## 🔧 Configuration

### Secrets (IMPORTANTE - À modifier en production !)

Le fichier `03-rabbitmq-broker-secret.yaml` contient les credentials par défaut :
- **Username**: `admin`
- **Password**: `RabbitMQ2024!`
- **Erlang Cookie**: `secure-cluster-cookie-2024`

**⚠️ CHANGEZ CES VALEURS EN PRODUCTION !**

```bash
# Créer de nouveaux secrets
echo -n "votre-username" | base64
echo -n "votre-password-securise" | base64
echo -n "votre-erlang-cookie-unique" | base64
```

### Ingress

Modifiez le hostname dans `09-rabbitmq-broker-ingress.yaml` :
```yaml
rules:
- host: rabbitmq.votre-domaine.com  # Changez ici
```

### Storage

Si vous avez une StorageClass spécifique, décommentez et modifiez dans `07-rabbitmq-broker-statefulset.yaml` :
```yaml
# storageClassName: fast-ssd  # Votre StorageClass
```

## 📈 Auto-Scaling

### Configuration HPA

Le HPA est configuré avec :
- **Min replicas**: 3
- **Max replicas**: 10
- **Scaling basé sur**:
    - CPU > 70%
    - Mémoire > 80%

### Scaling manuel

```bash
# Scale manuel
kubectl scale statefulset rabbitmq-broker --replicas=5 -n quizmeup

# Vérifier le scaling
kubectl get pods -n quizmeup -l app=rabbitmq-broker
```

### Monitoring du scaling

```bash
# Voir les événements HPA
kubectl describe hpa rabbitmq-broker-hpa -n quizmeup

# Voir les métriques en temps réel
kubectl top pods -n quizmeup -l app=rabbitmq-broker

# Voir les logs du HPA controller
kubectl logs -n kube-system -l app=horizontal-pod-autoscaler
```

## 🌐 Accès aux services

### Interface Web Management

1. **Via Ingress** (recommandé) :
   ```
   http://rabbitmq.quizmeup.local
   ```

2. **Via Port-Forward** :
   ```bash
   kubectl port-forward svc/rabbitmq-broker-service 15672:15672 -n quizmeup
   # Accès : http://localhost:15672
   ```

### Connexion AMQP

1. **Depuis le cluster** :
   ```
   amqp://admin:RabbitMQ2024!@rabbitmq-broker-service.quizmeup.svc.cluster.local:5672
   ```

2. **Via Port-Forward** :
   ```bash
   kubectl port-forward svc/rabbitmq-broker-service 5672:5672 -n quizmeup
   # Connexion : amqp://admin:RabbitMQ2024!@localhost:5672
   ```

## 📊 Monitoring

### Métriques Management UI

Les métriques sont disponibles via l'interface web de management :
```bash
# Accéder à l'interface de management
kubectl port-forward svc/rabbitmq-broker-service 15672:15672 -n quizmeup
# Interface : http://localhost:15672
```

### Monitoring via API Management

```bash
# API REST pour récupérer les métriques
curl -u admin:RabbitMQ2024! http://localhost:15672/api/overview
curl -u admin:RabbitMQ2024! http://localhost:15672/api/queues
curl -u admin:RabbitMQ2024! http://localhost:15672/api/nodes
```

### Commandes de diagnostic

```bash
# Statut du cluster
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmq-diagnostics cluster_status

# Liste des queues
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmqctl list_queues

# Statut des nœuds
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmqctl cluster_status

# Vérifier la santé
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmq-diagnostics health_check
```

## 🛠️ Maintenance

### Mise à jour

```bash
# Mise à jour de l'image
kubectl patch statefulset rabbitmq-broker -n quizmeup -p='{"spec":{"template":{"spec":{"containers":[{"name":"rabbitmq","image":"rabbitmq:3.13-management"}]}}}}'

# Vérifier le rollout
kubectl rollout status statefulset/rabbitmq-broker -n quizmeup
```

### Backup

```bash
# Backup des définitions
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmqctl export_definitions /tmp/definitions.json
kubectl cp quizmeup/rabbitmq-broker-0:/tmp/definitions.json ./backup-definitions.json
```

### Restauration

```bash
# Restaurer les définitions
kubectl cp ./backup-definitions.json quizmeup/rabbitmq-broker-0:/tmp/definitions.json
kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmqctl import_definitions /tmp/definitions.json
```

## 🚨 Troubleshooting

### Problèmes courants

1. **Pods en CrashLoopBackOff** :
   ```bash
   kubectl logs rabbitmq-broker-0 -n quizmeup
   kubectl describe pod rabbitmq-broker-0 -n quizmeup
   ```

2. **Problèmes de cluster** :
   ```bash
   # Vérifier la connectivité réseau
   kubectl exec rabbitmq-broker-0 -n quizmeup -- rabbitmq-diagnostics ping
   
   # Réinitialiser un nœud problématique
   kubectl exec rabbitmq-broker-1 -n quizmeup -- rabbitmqctl stop_app
   kubectl exec rabbitmq-broker-1 -n quizmeup -- rabbitmqctl reset
   kubectl exec rabbitmq-broker-1 -n quizmeup -- rabbitmqctl start_app
   ```

3. **HPA ne fonctionne pas** :
   ```bash
   # Vérifier Metrics Server
   kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
   
   # Vérifier les métriques des pods
   kubectl top pods -n quizmeup
   ```

### Logs

```bash
# Logs des pods RabbitMQ
kubectl logs -f rabbitmq-broker-0 -n quizmeup

# Logs de tous les pods du StatefulSet
kubectl logs -f -l app=rabbitmq-broker -n quizmeup

# Événements du namespace
kubectl get events -n quizmeup --sort-by='.lastTimestamp'
```

## 🗑️ Désinstallation

```bash
# Supprimer tous les ressources
kubectl delete -f .

# Ou supprimer le namespace complet (attention aux PVCs !)
kubectl delete namespace quizmeup

# Supprimer manuellement les PVCs si nécessaire
kubectl get pvc -n quizmeup
kubectl delete pvc -l app=rabbitmq-broker -n quizmeup
```

## 📚 Ressources

- [Documentation RabbitMQ](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ on Kubernetes](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## 🤝 Support

Pour les problèmes :
1. Vérifiez les logs avec les commandes ci-dessus
2. Consultez la documentation officielle
3. Ouvrez une issue avec les détails de votre environnement