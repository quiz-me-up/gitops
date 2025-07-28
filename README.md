# gitops

### DNS
```
*.quizmeup.local
*.quizmeup.dev
*.quizmeup
```

### Sealed Secrets
To create a sealed secret from a Kubernetes secret, you can use the `kubeseal`;
command: 
```bash

cat secret.yaml | kubeseal \
--format yaml \
--allow-empty-data \
> sealed-secret.yaml
```