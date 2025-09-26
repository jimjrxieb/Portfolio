# Projects

## Portfolio (this site)
- React/Vite UI + FastAPI API, deployed to Kubernetes
- Exposed via Cloudflare Tunnel; domain: **linksmlm.com**
- "Ask Me" queries hit a RAG endpoint that retrieves from my knowledge docs before LLM generation
- GitHub Actions pipeline handles CI/CD, container security scanning, and automated K8s deployments
- Uses small efficient LLM (Qwen2.5-1.5B-Instruct) optimized for Azure VM specs

## LinkOps-Afterlife (OSS)
- **Goal:** Make it easy to create a personal avatar—photo + voice + personality (via RAG)
- **Demo URL:** **demo.linksmlm.com** (planned via Cloudflare Tunnel)
- **Flow:** Upload an image and short voice recording; add notes that define tone/personality; RAG keeps responses aligned
- **Features:**
  - Voice recording & upload capability in browser
  - Personality tuning via RAG using custom knowledge bases  
  - Interactive avatar generation with AI-powered responses
  - Data preprocessing pipeline that sanitizes and chunks uploaded content
- **Architecture:** Runs locally/offline-friendly using small model; scales to larger hosted LLM when needed
- **Tech Stack:** FastAPI backend, React frontend, ChromaDB for RAG, sentence transformers for embeddings

## Current Infrastructure
- **Kubernetes cluster** running both Portfolio and Afterlife demos
- **Cloudflare Tunnel** for secure public exposure without load balancers
- **GitHub Actions** for CI/CD with security scanning integrated
- **Monitoring:** Prometheus + Grafana stack for observability
- **Security:** Trivy/Snyk scanning in pipelines, non-root containers, NetworkPolicies