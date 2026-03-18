# Deployment Configs

Kubernetes manifests for running vendor adapters as scheduled jobs.

## Files

| File | Purpose |
|------|---------|
| `cronjob.yaml` | CronJob for scheduled vendor polling |

## Usage

```bash
# Deploy Falcon polling CronJob (every 5 minutes)
kubectl apply -f deployment-configs/cronjob.yaml

# Check job status
kubectl get cronjobs -n gp-security
kubectl get jobs -n gp-security | grep vendor

# View logs from most recent run
kubectl logs -n gp-security $(kubectl get pods -n gp-security -l job-name -o jsonpath='{.items[-1].metadata.name}')
```
