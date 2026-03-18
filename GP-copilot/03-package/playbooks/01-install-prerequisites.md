# Playbook: Install Prerequisites

> Install all tools needed to deploy and operate the runtime security stack.
>
> **When:** Before touching the cluster.
> **Time:** ~5 min

---

## Step 1: Automated Install

```bash
PKG=~/GP-copilot/GP-CONSULTING/03-DEPLOY-RUNTIME

bash $PKG/tools/install-prerequisites.sh
```

This installs:

| Tool | Purpose | Required |
|------|---------|----------|
| `kubectl` | Kubernetes CLI | Yes |
| `helm` 3.x | Package manager for Falco + falco-exporter | Yes |
| Falco Helm repo | `falcosecurity/charts` | Yes |
| `jq` | JSON parsing for logs and alerts | Yes |
| `yq` | YAML editing for Helm values | Recommended |
| `python3` + `pyyaml` | YAML validation in `tune-falco.sh` | Recommended |
| `python3` + `requests` | Prometheus queries in `generate-report.py` | Optional |

---

## Step 2: Check-Only Mode (Audit Without Installing)

```bash
bash $PKG/tools/install-prerequisites.sh --check
```

---

## Step 3: Skip Options

```bash
# Skip Python if you won't use generate-report.py
bash $PKG/tools/install-prerequisites.sh --skip-python

# Skip kubectl if managed externally (e.g., cloud shell)
bash $PKG/tools/install-prerequisites.sh --skip-kubectl
```

---

## Alternative: Container Toolkit

Skip local prerequisites entirely — run everything from the pre-built container image:

```bash
# Docker (local testing)
docker run -it -v ~/.kube/config:/home/toolkit/.kube/config \
  gp-copilot/runtime-toolkit bash

# In-cluster pod (production)
kubectl apply -f $PKG/templates/deployment-configs/toolbox-pod.yaml
kubectl exec -it runtime-toolkit -n gp-security -- bash
```

The container image includes kubectl, helm, jq, yq, and all Python deps.

---

## Step 4: Verify

```bash
kubectl version --client
helm version --short
jq --version
python3 --version
kubectl cluster-info
kubectl get nodes
```

---

## Next Steps

- Deploy Falco → [02-deploy-falco.md](02-deploy-falco.md)

---

*Ghost Protocol — Runtime Security Package (CKS)*
