# DevOps experience — how is the platform built?
- **Codebase**: FastAPI (API), React (UI), modular engines (LLM/RAG/TTS/Avatar)
- **CI/CD**: GitHub Actions + Azure Pipelines (lint, type-check, SAST, container scan, SBOM, image push)
- **Containers**: Dockerfiles for API/UI; multi-arch builds to GHCR
- **Deploy**: Kubernetes on Azure VM (ingress + TLS), optional Helm charts
- **GitOps**: ArgoCD to pull from main; values override per env
- **Observability**: Prometheus (metrics), Grafana (dashboards), health probes, structured logs
- **Security**: Dependabot/OSV, Trivy scan, least-priv. GH tokens, WAF/Rate limit at edge

# Why Claude and heavy lint/security?
I used Claude to accelerate scaffolding, but enforced strict lint/type-check/security gates:
- Pre-commit hooks + CI gates (flake8/ruff/mypy/eslint)
- Trivy/Grype container scans
- SBOM + image signing (cosign) on deploy paths