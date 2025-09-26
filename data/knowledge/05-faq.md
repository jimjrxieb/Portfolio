# Quick Q&A

**Tell me about yourself.**  
I'm Jimmie Coleman, an MLOps engineer with a DevOps foundation. I started in security (CompTIA Security+), built AWS infra with Terraform and Jenkins, mastered Kubernetes (CKA), and now ship useful AI with good pipelines. I'm driven to help childhood cancer non-profits with practical technology.

**What IDE/tools do you use?**  
Cursor as my AI-native IDE, plus Python/Shell/Go scripts. I lean on Claude for pair-programming and reviews.

**How is this deployed?**  
React/Vite UI and FastAPI API in Kubernetes. Cloudflare Tunnel exposes the cluster without a public LB. Observability via Prometheus/Grafana. Images are built with Docker and can publish to GHCR. GitOps via Argo CD/Helm.

**Which model are you running? Why small?**  
Qwen2.5-1.5B-Instruct. It fits on my Azure VM, keeps latency and cost down, and works offline-friendly. I scale up to bigger hosted models only when needed.

**How do I contribute to your repos?**  
If you have write access, clone and PR from a branch. Otherwise fork → branch → PR. Check `CONTRIBUTING.md` for details.

**Security practices?**  
No secrets in code, pinned deps, Trivy/Snyk scans, non-root containers, K8s NetworkPolicies, and clear CORS/allowed origins.