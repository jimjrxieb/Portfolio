# Playbook 04: Platform Services

> Derived from [GP-CONSULTING/02-CLUSTER-HARDENING/playbooks/09-13](https://github.com/jimjrxieb/GP-copilot) (Gateway API, External Secrets, Backstage, Namespace-as-a-Service, Golden Path)
> Tailored for the Portfolio k3s cluster (portfolioserver)

## What This Does

After hardening (Playbooks 01-03), this playbook adds platform engineering services that make the cluster self-service and consistent. These are the CNPA-level capabilities that turn a hardened cluster into a developer platform.

## Services on Portfolio

### 1. Gateway API (Traefik → Gateway API Migration)

Portfolio recently migrated from Ingress to Gateway API:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: portfolio-gateway
  namespace: portfolio
spec:
  gatewayClassName: traefik
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - name: linksmlm-tls
```

**Why Gateway API over Ingress:**
- Role separation: Platform team owns Gateway, app team owns HTTPRoutes
- Per-listener TLS (different certs per domain)
- Traffic splitting for canary deployments (90/10)
- Standard API across all implementations (Traefik, Envoy, Istio, Cilium)

### 2. External Secrets Operator (ESO)

Already deployed in `external-secrets` namespace. Syncs secrets from external stores into K8s:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
  namespace: portfolio
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: api-secrets
  data:
    - secretKey: CLAUDE_API_KEY
      remoteRef:
        key: portfolio/api
        property: claude_api_key
```

**Why ESO:** Secrets rotate in Vault → ESO syncs automatically → no manual `kubectl create secret`. NIST IA-5 compliant.

### 3. ArgoCD GitOps

Already deployed in `argocd` namespace. Manages all Portfolio deployments:

```
GitHub (source of truth)
  → ArgoCD detects change (3 min poll or manual sync)
  → Helm template rendered
  → Diff against live state
  → Rolling update applied
  → Self-heal if someone edits live state manually
```

**ArgoCD CLI** installed on server for manual operations:
```bash
argocd app get portfolio        # Check status
argocd app sync portfolio       # Force sync
argocd app diff portfolio       # See what's different
argocd app history portfolio    # View deploy history
```

### 4. cert-manager

Already deployed. Manages TLS certificates via Let's Encrypt:

```
cert-manager watches Ingress/Gateway annotations
  → Requests cert from Let's Encrypt (ACME HTTP-01)
  → Stores in K8s Secret
  → Auto-renews before expiry
```

### 5. Monitoring Stack

Prometheus + Grafana in `monitoring` namespace:
- **Prometheus**: Scrapes metrics from all namespaces
- **Grafana**: Dashboards for cluster health, ArgoCD sync, Falco alerts

## CNPA Exam Alignment

| CNPA Domain | What Portfolio Demonstrates |
|------------|---------------------------|
| **Platform as a Product** | Self-service deployment via ArgoCD GitOps |
| **Developer Experience** | Push to main → live in 4 minutes (CI/CD → ArgoCD) |
| **Platform Capabilities** | Gateway API, ESO, cert-manager, monitoring |
| **Observability** | Prometheus + Grafana + structured logging |
| **Security** | Gatekeeper admission, PSS, NetworkPolicy, ESO for secrets |
| **GitOps** | ArgoCD with auto-sync, self-heal, prune |

## What GP-CONSULTING Adds Beyond Current Setup

| Capability | Current State | GP-Enhanced |
|-----------|--------------|-------------|
| Namespace provisioning | Manual `kubectl create ns` | Namespace-as-a-Service CRD (auto-provisions NS + policies + quotas) |
| New service deploy | Manual Helm chart creation | Golden Path template (30-second stamp-out with security baked in) |
| Developer portal | None | Backstage IDP (catalog, software templates, TechDocs) |
| Traffic management | Basic routing | Canary deployments with Gateway API traffic splitting |
