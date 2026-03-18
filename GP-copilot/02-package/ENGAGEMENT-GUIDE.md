# K8s Package Engagement Guide

> Source of truth for K8s + IaC hardening (CKA + CKS best practices).
> Tools read policies from this directory — no copying configs needed.

---

## What This Package Does

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEFENSE IN DEPTH LAYERS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  LAYER 0 — Node Hardening (before K8s config)                       │
│  node-hardening/harden-nodes.sh (Ansible)                           │
│  → CIS node-level: sysctl, auditd, kubelet, kernel modules         │
│  → Kubernetes can't reach this layer. Ansible fills the gap.        │
│                                                                      │
│  LAYER 1 — CI/CD (before merge)                                     │
│  setup-cicd.sh copies conftest Rego → client repo                   │
│  → Blocks non-compliant K8s YAML before it reaches the cluster     │
│                                                                      │
│  LAYER 2 — Admission (at kubectl apply)                             │
│  Kyverno ClusterPolicies or OPA Gatekeeper Constraints              │
│  → Blocks non-compliant workloads at the API server                 │
│                                                                      │
│  LAYER 3 — IaC (Terraform/CloudFormation)                           │
│  conftest test *.tf --policy templates/policies/terraform/            │
│  → Blocks misconfigured cloud infra before apply                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Engagement flow:** Harden nodes → Audit cluster → Wire CI/CD → Deploy admission control → Fix → Enforce

---

## Engagement Timeline

| Phase | Playbook | When | What Happens |
|-------|----------|------|-------------|
| 0 | [01-cluster-audit](playbooks/01-cluster-audit.md) | Day 1 | Deploy tools, run kube-bench + Kubescape + Polaris, get baseline |
| 0.5 | [02-node-hardening](playbooks/02-node-hardening.md) | Day 1 | Ansible: CIS sysctl, auditd, kubelet hardening |
| 1 | [03-automated-fixes](playbooks/03-automated-fixes.md) | Day 1-2 | One-shot: NetworkPolicy, LimitRange, PSS labels |
| 2 | [04-fix-manifests](playbooks/04-fix-manifests.md) | Day 2-3 | Per-finding: securityContext, limits, probes, pull policy |
| 3 | [05-deploy-admission-control](playbooks/05-deploy-admission-control.md) | Week 1 | Kyverno or Gatekeeper in audit mode |
| 4 | [06-wire-cicd](playbooks/06-wire-cicd.md) | Week 1 | Conftest Rego in client's CI pipeline |
| 5 | [07-audit-to-enforce](playbooks/07-audit-to-enforce.md) | Week 2-4 | Progressive enforcement (critical → high → all) |
| 6 | [08-compliance-report](playbooks/08-compliance-report.md) | Final | Before/after comparison, client deliverable |
| 7 | [09-deploy-gateway-api](playbooks/09-deploy-gateway-api.md) | Week 1 | Install Gateway API CRDs, deploy controller, TLS policy |
| 8 | [10-setup-external-secrets](playbooks/10-setup-external-secrets.md) | Week 1 | ESO install, ClusterSecretStore, enforce ESO-only |
| 9 | [11-deploy-backstage](playbooks/11-deploy-backstage.md) | Week 2 | Internal Developer Platform — catalog, templates, TechDocs |
| 10 | [12-namespace-as-a-service](playbooks/12-namespace-as-a-service.md) | Week 2 | TeamNamespace CRD + operator — self-service namespaces |

---

## Platform Engineering (CNPA) Enhancements

These enhancements close CNPA (Cloud Native Platform Engineering) exam domain gaps
and give dev teams self-service capabilities with guardrails.

| Enhancement | What It Adds | Self-Service? |
|-------------|-------------|---------------|
| **Gateway API** | GatewayClass/Gateway/HTTPRoute, canary routing, TLS enforcement | HTTPRoutes (app team) |
| **External Secrets** | ESO + ClusterSecretStore, native Secret ban policy | ExternalSecret CRs (app team) |
| **Namespace-as-a-Service** | TeamNamespace CRD → Namespace + NetworkPolicy + LimitRange + ResourceQuota + RBAC | TeamNamespace CR (app team) |
| **Backstage IDP** | Service catalog, software templates (golden paths), TechDocs, K8s plugin | Full self-service portal |

```bash
# Gateway API
bash $PKG/tools/platform/setup-gateway-api.sh --controller envoy --dry-run

# External Secrets
bash $PKG/tools/platform/setup-external-secrets.sh --backend aws --dry-run

# Namespace-as-a-Service
bash $PKG/tools/platform/deploy-namespace-operator.sh --test

# Backstage
bash $PKG/tools/platform/setup-backstage.sh --domain portal.client.com --dry-run
bash $PKG/tools/platform/register-service.sh --app-name myapp --team payments --output-only
```

---

## Three Deployment Scenarios

### Scenario A: Managed K8s (EKS, GKE, AKS)

Tools run from **your rig**. Results write directly to GP-S3.

```bash
aws eks update-kubeconfig --name my-cluster --region us-east-1
kubectl cluster-info
bash $PKG/tools/hardening/install-scanners.sh --cluster
```

### Scenario B: Self-hosted K8s (k3s, kubeadm, bare metal)

Tools run **on the server** via SSH. Results stage on server, pull back to GP-S3.

```bash
scp $PKG/tools/hardening/install-scanners.sh user@server:~/
ssh user@server 'bash ~/install-scanners.sh --cluster'
```

Also SCP the fix scripts + templates:
```bash
ssh user@server 'mkdir -p ~/02-CLUSTER-HARDENING/tools ~/02-CLUSTER-HARDENING/templates/remediation'
scp $PKG/tools/hardening/fix-cluster-security.sh user@server:~/02-CLUSTER-HARDENING/tools/hardening/
scp $PKG/templates/remediation/*.yaml user@server:~/02-CLUSTER-HARDENING/templates/remediation/
```

### Scenario C: Container Toolkit (recommended for self-hosted)

No tool installation. Deploy toolkit as a pod — all tools baked into image.

```bash
scp $PKG/tools/toolbox-pod.yaml ubuntu@<server-ip>:/tmp/
ssh ubuntu@<server-ip> 'kubectl apply -f /tmp/toolbox-pod.yaml && \
  kubectl wait --for=condition=Ready pod/cluster-toolkit -n gp-security --timeout=60s'
kubectl exec -it cluster-toolkit -n gp-security -- bash
```

**What it deploys:** Namespace, ServiceAccount, ClusterRole/Binding, NetworkPolicy, PVC (1Gi), Pod.

---

## Tested Results

### portfolioserver (Mar 2026, k3s v1.34.3, 1 node, 37 pods)

| Metric | Before | After |
|--------|--------|-------|
| Polaris | 82/100 | 82/100 |
| NetworkPolicies | 8 | 30 |
| LimitRanges | 0 | 7 |
| ResourceQuotas | 1 | 8 |
| PSS-labeled namespaces | 2 | 11 |
| Namespaces without NetworkPolicy | 9 | 1 |

### EKS Anywhere (Feb 2026, v1.34)

| Metric | Before | After |
|--------|--------|-------|
| Polaris | 81/100 | 82/100 |
| NetworkPolicies | 0 | 18 |
| Gatekeeper constraints | 0 | 3 (audit) |
| kube-bench | 24 PASS / 3 FAIL | improved |

---

## CKS + CKA Coverage

| Domain | Tools / Templates |
|--------|-------------------|
| **CKS — Cluster Hardening** | disallow-privilege-escalation, require-pss-labels, kube-bench |
| **CKS — System Hardening** | require-seccomp-strict, require-apparmor-profile |
| **CKS — Microservice Vulns** | require-run-as-nonroot, require-runtime-class-untrusted |
| **CKS — Supply Chain** | disallow-latest-tag, cicd-security.rego, image-security.rego |
| **CKS — Runtime Security** | require-seccomp-strict, require-readonly-rootfs |
| **CKS — Network** | network-policies.yaml, prohibit-insecure-services.rego |
| **CKA — Resource Mgmt** | require-resource-limits, resource-management.yaml |
| **CKA — Availability** | availability.yaml (PDB + HPA) |
| **CKA — RBAC** | rbac-templates.yaml, RBAC audit in run-cluster-audit.sh |

Full compliance map: `templates/compliance-mappings/cks_exam_domains.yaml`
Coverage report: `python3 tools/admission/policy-coverage-report.py --framework cks`

---

## Quick Reference — All Commands

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING
REPORTS=~/GP-copilot/GP-S3/5-consulting-reports/<client>

# Audit
bash $PKG/tools/hardening/run-cluster-audit.sh --output $REPORTS/k8s-audit-$(date +%Y%m%d).md

# Automated fixes
bash $PKG/tools/hardening/fix-cluster-security.sh --dry-run
bash $PKG/tools/hardening/fix-cluster-security.sh

# Deploy admission control
bash $PKG/tools/admission/deploy-policies.sh --engine kyverno --mode audit

# Wire CI/CD
bash $PKG/tools/platform/setup-cicd.sh --client-repo <repo> --manifests-dir k8s

# Scaffold app deployments (Kustomize + ArgoCD)
bash $PKG/tools/platform/create-app-deployment.sh \
  --app-name myapp --image ghcr.io/org/myapp:v1.0 --port 8080

# Configure ArgoCD
bash $PKG/tools/platform/setup-argocd.sh --namespace argocd

# Gateway API
bash $PKG/tools/platform/setup-gateway-api.sh --controller envoy

# External Secrets Operator
bash $PKG/tools/platform/setup-external-secrets.sh --backend aws

# Namespace-as-a-Service
bash $PKG/tools/platform/deploy-namespace-operator.sh

# Backstage IDP
bash $PKG/tools/platform/setup-backstage.sh --domain portal.client.com
bash $PKG/tools/platform/register-service.sh --app-name myapp --team payments --repo-url https://github.com/org/myapp

# Enforce
bash $PKG/tools/admission/audit-to-enforce.sh --strategy critical-first

# Compliance report
python3 $PKG/tools/admission/policy-coverage-report.py --framework all --output $REPORTS/compliance.md

# Monitoring
kubectl apply -f $PKG/monitoring/policy-alerts.yaml
```

---

## Troubleshooting

### Policy blocking a valid deployment

```bash
kubectl get policyreport -n <namespace> -o yaml           # See what's blocking
# Fix the workload (preferred), create PolicyException, or revert to audit (last resort)
```

### Policy engine down

```bash
kubectl get pods -n kyverno
kubectl logs -n kyverno deploy/kyverno --tail=50
kubectl rollout restart -n kyverno deploy/kyverno
```

### Too many violations — where to start

1. Run `generate-fix-report.sh` — highest count = fix first
2. Apply Kyverno mutations: `kubectl apply -f $PKG/templates/policies/kyverno/mutations.yaml`
3. PSS labels: `kubectl apply -f $PKG/templates/remediation/pss-namespace-labels.yaml`
4. Network policies: `kubectl apply -f $PKG/templates/remediation/network-policies.yaml`
5. ResourceQuota + LimitRange: `kubectl apply -f $PKG/templates/remediation/resource-management.yaml -n <ns>`

---

*Ghost Protocol — K8s Hardening Package (CKA + CKS)*
