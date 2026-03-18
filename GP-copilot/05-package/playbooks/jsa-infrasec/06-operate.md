# Phase 6: Autonomous Platform Services

Source playbooks: `02-CLUSTER-HARDENING/playbooks/10-17a`
Automation level: **40% autonomous (D-rank)**, 40% JADE (C-rank), 16% human (B-rank), 4% human-only (S-rank)
**Optional phase** — deployed based on engagement scope

## What This Phase Covers

Platform services that build on the hardened cluster from Phases 1-5.
Each service is independently deployable. Agent checks prerequisites before each.

```
10. Gateway API         ← Network ingress, TLS termination, canary
11. External Secrets    ← Secrets management (Vault, AWS SM, etc.)
12. Backstage           ← Developer portal, service catalog
13. Namespace-as-a-Service ← Self-service namespace provisioning
14. Golden Path         ← Kustomize deployment scaffolds
15. Secrets Hygiene     ← Orphan cleanup, automount audit
16. Kyverno Cleanup     ← Fix CronJob failures
17. GitOps Workflow     ← ArgoCD promotion pipeline
17a. Deploy Staging     ← Staging with prod-class security
```

## Service: Gateway API (Playbook 10)

### C-rank: Controller Selection (JADE)
```
JADE: recommend based on CNI and existing ingress.
  Cilium CNI → Cilium Gateway
  Other CNI → Envoy Gateway
  Existing nginx-ingress → migration path
```

### D-rank: Deploy
```bash
02-CLUSTER-HARDENING/tools/platform/setup-gateway-api.sh --controller ${CONTROLLER}
kubectl get gatewayclass  # verify
```

### C-rank: TLS Configuration (JADE)
```
JADE: detect cert infrastructure.
  cert-manager installed → use cert-manager ClusterIssuer
  AWS → ACM
  Manual → self-signed for dev, Let's Encrypt for prod
```

## Service: External Secrets (Playbook 11)

### C-rank: Backend Selection (JADE)
```
JADE: recommend based on cloud provider.
  AWS → AWS Secrets Manager
  Azure → Key Vault
  Self-hosted → Vault
  No preference → Vault (most portable)
```

### D-rank: Deploy ESO
```bash
02-CLUSTER-HARDENING/tools/platform/setup-external-secrets.sh --backend ${BACKEND}
kubectl get clustersecretstore  # verify
```

### B-rank: Authentication
```
ESCALATE to human:
  "ESO needs backend credentials."
  Options: provide credentials, use IRSA/workload identity, skip ESO.
```

## Service: Backstage (Playbook 12)

### D-rank: Deploy
```bash
02-CLUSTER-HARDENING/tools/platform/setup-backstage.sh
kubectl get pods -l app.kubernetes.io/name=backstage  # verify
```

### C-rank: Configuration (JADE)
```
JADE: generate app-config.yaml.
  - Domain from ingress/gateway
  - OAuth from existing identity provider
  - Catalog from discovered services + golden-path templates
```

## Service: Namespace-as-a-Service (Playbook 13)

### D-rank: Deploy Operator
```bash
02-CLUSTER-HARDENING/tools/platform/deploy-namespace-operator.sh
kubectl get crd teamnamespaces.platform.gp-copilot.io  # verify
```

### C-rank: Tier Assignment (JADE)
```
JADE: define resource tiers.
  Small (dev):    cpu=2, mem=4Gi, pods=20
  Medium (stage): cpu=8, mem=16Gi, pods=50
  Large (prod):   cpu=16, mem=32Gi, pods=100

  Based on: cluster capacity, workload count, environment type.
```

## Service: Golden Path (Playbook 14)

### D-rank: Scaffold
```bash
02-CLUSTER-HARDENING/tools/platform/create-app-deployment.sh \
  --name ${APP_NAME} --namespace ${NAMESPACE}

# Generates: base/ + overlays/dev|staging|prod + argocd/application.yaml
```

### C-rank: App Values (JADE)
```
JADE: set app-specific port, health path, resource sizing.
  Read Dockerfile EXPOSE, detect health endpoint, estimate resources.
```

## Service: Secrets Hygiene (Playbook 15)

### D-rank: Scan
```bash
02-CLUSTER-HARDENING/tools/hardening/cleanup-orphaned-secrets.sh --dry-run
```

### C-rank: Cleanup (JADE)
```
JADE: verify each orphan has zero references.
  Check: no pod mount, no env valueFrom, no ESO reference, no Helm reference.
  Approve only truly orphaned secrets.
```

## Service: Kyverno Cleanup (Playbook 16)

Fully autonomous — D-rank.

```bash
# Diagnose CronJob failures
02-CLUSTER-HARDENING/tools/hardening/fix-kyverno-cleanup-jobs.sh --diagnose

# Fix image version mismatch
02-CLUSTER-HARDENING/tools/hardening/fix-kyverno-cleanup-jobs.sh --fix

# Verify
kubectl get cronjobs -n kyverno
kubectl get jobs -n kyverno --sort-by='.metadata.creationTimestamp' | tail -5
```

## Service: GitOps Workflow (Playbook 17)

### D-rank: Pipeline Setup
```bash
02-CLUSTER-HARDENING/tools/platform/promote-image.sh --setup
```

### B-rank: Promotion Gates
```
ESCALATE to human:
  "Promotion gates define who can approve staging→prod."
  Options: PR-based, JADE+human, manual only.
```

## Service: Deploy Staging (Playbook 17a)

### D-rank: Deploy
```bash
02-CLUSTER-HARDENING/tools/platform/deploy-stage.sh \
  --chart ${CHART} --values ${VALUES} --namespace staging
```

### D-rank: Security Scan
```bash
kubescape scan --include-namespaces staging
```

### B-rank: Security Validation
```
ESCALATE to human:
  "Staging deployed. Verify security posture matches prod requirements."
  Provide: scan results, pod status, policy violations, NetworkPolicy state.
```

## Phase 6 Summary

| Service | D-rank | C-rank | B-rank | S-rank |
|---------|--------|--------|--------|--------|
| Gateway API | 1 | 2 | — | — |
| External Secrets | 1 | 1 | 1 | — |
| Backstage | 1 | 1 | — | — |
| NaaS | 1 | 1 | — | — |
| Golden Path | 1 | 1 | — | — |
| Secrets Hygiene | 1 | 1 | — | — |
| Kyverno Cleanup | 2 | — | — | — |
| GitOps Workflow | 1 | — | 1 | — |
| Deploy Staging | 2 | — | 1 | — |
| **Total** | **11** | **7** | **3** | **0** |
