# Golden Dev Path

Plug-and-play guides for developers deploying apps on a GP-hardened platform.

**You are the developer.** The platform engineer already set up the cluster, Gateway API, policies, and guardrails. Your job is to deploy your app safely using the resources they've provided.

## Guides

| Guide | What It Covers | Type |
|-------|---------------|------|
| [01-gateway-api-routing.md](01-gateway-api-routing.md) | Expose your app with Gateway API (HTTPRoute, path routing, prefix stripping) | Industry Standard |
| [02-helm-chart-security.md](02-helm-chart-security.md) | Security context, resource limits, probes, service accounts | Industry Standard |
| [03-argocd-gitops-deploy.md](03-argocd-gitops-deploy.md) | ArgoCD application setup, auto-sync, image tag updates | Industry Standard |
| [04-network-policy.md](04-network-policy.md) | Zero-trust NetworkPolicy for your namespace | Industry Standard |

### Why a developer picks GP-Copilot over doing it themselves

Every guide above is industry standard. A senior dev could figure this out from Kubernetes docs in a week. Here's what they can't get anywhere else:

**What GP-Copilot provides that makes these guides worth using:**

| GP-Copilot Value-Add | What It Means for the Developer |
|----------------------|--------------------------------|
| **Golden path stamp-out** | `create-app-deployment.sh` generates all of the above in 30 seconds. Dev never writes YAML. |
| **Security baked in, not bolted on** | `base/` has non-root, drop ALL, read-only rootfs, seccomp, NetworkPolicy — developer gets it for free without knowing K8s security |
| **Kyverno catches mistakes before deploy** | Dev pushes a privileged container? Rejected at admission. No runtime surprise. |
| **Kustomize overlays = dev just changes image tag** | Dev doesn't touch security contexts, netpols, RBAC. They change one line (`newTag: v1.43.0`), push, ArgoCD deploys. |
| **Promote with one command** | `promote-image.sh --from dev --to staging` — no manual YAML editing across environments |
| **Pre-configured CI gates** | Drop our `ci-templates/` into `.github/workflows/` — 8 scanners as blocking checks, zero config |
| **Fixer scripts for findings** | Scanner finds MD5 hashing? We provide `fix-md5.py`. CVE in deps? We provide `bump-cves.sh`. Dev doesn't research fixes. |
| **FedRAMP/SOC2 compliance built into the platform** | Dev deploys normally. The platform produces the compliance evidence automatically. No extra work. |

**The pitch:** "You deploy like normal. Push code, change image tag, ArgoCD syncs. Everything else — security contexts, network policies, admission control, compliance evidence, vulnerability remediation — is handled by the platform. You don't think about security. The platform thinks about it for you."

That's why a developer picks this environment. Not because the guides are better — but because the platform does the work the guides describe, automatically.

## What the Platform Engineer Already Did (You Don't Touch This)

- GatewayClass (`gp-gateway`) — cluster-scoped, points to the ingress controller
- Traefik / Envoy / Cilium Gateway provider — enabled and running
- Kyverno policies — enforce TLS, block wildcards, require security contexts
- cert-manager — auto-provisions TLS certificates
- Monitoring — Prometheus + Grafana dashboards
- Golden path templates — Kustomize base with full hardening baked in
- ArgoCD — watches your overlay, syncs on push
- Falco — runtime threat detection watching your containers 24/7

## What You Own

- **Image tag** — which version of your app runs (that's it, really)
- **HTTPRoute** — your path routing rules (which URLs go to which services)
- **Environment variables** — app config in your overlay
- **Replica count** — how many pods in dev (staging/prod is platform-managed)

## What You Don't Touch

- **Security contexts** — baked into `base/`, enforced by Kyverno
- **NetworkPolicy** — generated per-service, only allows what your app needs
- **Service type** — always ClusterIP (never NodePort or LoadBalancer)
- **RBAC** — dedicated ServiceAccount per service, automount disabled
- **Resource limits** — set per environment in overlays by platform team
