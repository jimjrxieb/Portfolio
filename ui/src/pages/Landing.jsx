import ChatPanel from '../components/ChatPanel.tsx';
import Projects from '../components/Projects.tsx';

export default function Landing() {
  return (
    <div
      className="min-h-screen bg-gradient-to-br from-ink via-ink to-crystal-900"
      data-dev="landing"
    >
      {/* Header */}
      <div className="relative z-10 p-6">
        <div className="max-w-7xl mx-auto">
          <div className="flex items-center justify-end">
            <div className="text-right">
              <p className="text-gojo-primary text-sm font-medium">
                Jimmie Coleman
              </p>
              <p className="text-gojo-secondary text-xs">
                LinkOps AI-BOX • DevSecOps
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-8">
            {/* Left Panel - Welcome & Chat */}
            <div className="space-y-6">
              {/* Welcome Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <div className="mb-6">
                  <h1 className="text-gojo-primary font-bold text-2xl mb-2">
                    Jimmie Coleman Portfolio
                  </h1>
                  <p className="text-gojo-secondary mb-4">
                    DevSecOps Engineer & AI Solutions Architect
                  </p>
                  <div className="flex gap-4 text-sm">
                    <a
                      href="https://www.linkedin.com/in/jimmie-coleman-jr-564a8a199/"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-crystal-400 hover:text-crystal-300 underline"
                    >
                      LinkedIn
                    </a>
                    <a
                      href="https://github.com/jimjrxieb"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-crystal-400 hover:text-crystal-300 underline"
                    >
                      GitHub
                    </a>
                  </div>
                </div>

                {/* Professional Overview */}
                <div className="bg-snow/10 rounded-lg p-4 border border-white/5">
                  <h3 className="text-gojo-primary font-semibold mb-2">
                    Production AI Portfolio Platform
                  </h3>
                  <p className="text-crystal-400 text-sm mb-3">
                    Full-Stack RAG System | Enterprise DevSecOps | Policy-as-Code
                  </p>
                  <p className="text-gojo-secondary text-xs leading-relaxed mb-3">
                    <strong className="text-gojo-primary">DevSecOps Implementation:</strong> This project demonstrates production-ready DevSecOps workflows with comprehensive security automation throughout the development lifecycle. The CI/CD pipeline leverages GitHub Actions with parallel security scanning (detect-secrets for secrets detection, Semgrep for SAST analysis, Trivy for container vulnerability scanning, Bandit for Python security, and Safety for dependency vulnerabilities). Policy-as-Code is enforced through OPA/Conftest in CI (13 policies with 11 automated tests validating Kubernetes manifests) and Gatekeeper for runtime admission control. Infrastructure is deployed using three progressive methods—simple kubectl manifests, Terraform with LocalStack for AWS service simulation, and production-grade Helm charts with ArgoCD GitOps—showcasing the evolution from beginner to enterprise approaches. Security is hardened with Kubernetes Network Policies, RBAC, Pod Security Standards, non-root Docker containers with multi-stage builds, and pre-commit hooks preventing secret commits. Public access is secured through Cloudflare Tunnel, eliminating exposed ports while maintaining TLS encryption.
                  </p>
                  <p className="text-gojo-secondary text-xs leading-relaxed mb-4">
                    <strong className="text-gojo-primary">AI/ML Architecture:</strong> The system implements a production RAG (Retrieval-Augmented Generation) pipeline using ChromaDB as the vector database with 2,656+ embeddings generated from comprehensive technical documentation. Ollama (nomic-embed-text model) handles local embedding generation for 768-dimensional vectors, while Claude API (Anthropic&apos;s claude-3-haiku-20240307) serves as the production LLM for natural language responses. The FastAPI backend provides async endpoints with semantic search completing in &lt;100ms, processing user queries through ChromaDB similarity search, context retrieval, and LLM response generation with source citations. The ingestion pipeline processes markdown documents through sanitization, intelligent chunking (1000 words with 200-word overlap), embedding generation, and storage in versioned ChromaDB collections supporting atomic swaps for zero-downtime updates. The React/Vite frontend delivers real-time chat with a professional AI assistant (Sheyla) trained on DevSecOps expertise, project portfolios, and technical knowledge, demonstrating practical applications of modern AI/ML technologies in production environments.
                  </p>

                  {/* Key Features */}
                  <div className="mt-4 pt-4 border-t border-white/10">
                    <h4 className="text-gojo-primary font-semibold text-sm mb-2">
                      Key Features
                    </h4>
                    <div className="grid grid-cols-1 gap-1 text-xs">
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Semantic Search:</strong> ChromaDB vector database with 2,656+ embeddings, &lt;100ms query response time</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Production LLM:</strong> Claude API (Anthropic) with Haiku model for cost-optimized inference</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Local Embeddings:</strong> Ollama nomic-embed-text for 768-dimensional vector generation</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Policy Enforcement:</strong> OPA/Conftest CI validation + Gatekeeper runtime admission control</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Security Automation:</strong> 6-tool security pipeline (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit)</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>GitOps Deployment:</strong> Three deployment methods showing kubectl → Terraform → Helm+ArgoCD progression</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Zero-Downtime Updates:</strong> Versioned ChromaDB collections with atomic swaps</span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-crystal-400 mt-0.5">•</span>
                        <span className="text-gojo-secondary"><strong>Secrets Management:</strong> Automated sync from .env to Kubernetes secrets with pre-commit validation</span>
                      </div>
                    </div>
                  </div>

                  {/* Architecture */}
                  <div className="mt-4 pt-4 border-t border-white/10">
                    <h4 className="text-gojo-primary font-semibold text-sm mb-2">
                      Architecture
                    </h4>

                    {/* Technology Stack */}
                    <div className="mb-3">
                      <h5 className="text-crystal-400 font-medium text-xs mb-1">Backend (Python 3.11)</h5>
                      <div className="text-gojo-secondary text-xs space-y-0.5">
                        <div>• FastAPI + Uvicorn (async web framework)</div>
                        <div>• ChromaDB 0.5.18+ (vector database, persistent SQLite storage)</div>
                        <div>• Anthropic Claude API (claude-3-haiku-20240307 for production LLM)</div>
                        <div>• Ollama (nomic-embed-text for 768-dim local embeddings)</div>
                        <div>• Pydantic (request/response validation)</div>
                      </div>
                    </div>

                    <div className="mb-3">
                      <h5 className="text-crystal-400 font-medium text-xs mb-1">Frontend (TypeScript/React)</h5>
                      <div className="text-gojo-secondary text-xs space-y-0.5">
                        <div>• React 18.2.0 + TypeScript</div>
                        <div>• Vite 6.4.1 (build tool, esbuild 0.27.0)</div>
                        <div>• Material-UI 7.3.2 + Tailwind CSS 4.1.12</div>
                        <div>• Nginx (production static file serving)</div>
                      </div>
                    </div>

                    <div className="mb-3">
                      <h5 className="text-crystal-400 font-medium text-xs mb-1">Infrastructure &amp; Security</h5>
                      <div className="text-gojo-secondary text-xs space-y-0.5">
                        <div>• Docker (multi-stage builds, non-root containers, distroless base images)</div>
                        <div>• Kubernetes (Docker Desktop, 3-pod architecture: UI, API, ChromaDB)</div>
                        <div>• GitHub Actions (parallel security scanning: detect-secrets, Semgrep, Trivy, Bandit, Safety)</div>
                        <div>• OPA/Conftest (CI policy validation, 13 policies with 11 automated tests)</div>
                        <div>• Gatekeeper (runtime admission control)</div>
                        <div>• Cloudflare Tunnel (TLS-encrypted public access)</div>
                        <div>• Pre-commit hooks (secrets detection, linting)</div>
                      </div>
                    </div>

                    <div className="mb-3">
                      <h5 className="text-crystal-400 font-medium text-xs mb-1">Deployment Methods (Progressive Complexity)</h5>
                      <div className="text-gojo-secondary text-xs space-y-0.5">
                        <div>1. Method 1: Simple kubectl manifests (beginner-friendly)</div>
                        <div>2. Method 2: Terraform + LocalStack (AWS service simulation)</div>
                        <div>3. Method 3: Helm + ArgoCD (production GitOps)</div>
                      </div>
                    </div>

                    <div>
                      <h5 className="text-crystal-400 font-medium text-xs mb-1">System Components</h5>
                      <pre className="text-gojo-secondary text-xs overflow-x-auto bg-ink/50 p-2 rounded border border-white/5">
{`Portfolio/
├── api/                      # FastAPI backend
│   ├── routes/              # API endpoints (chat, RAG, health, uploads)
│   ├── engines/             # Core logic (LLM, RAG, conversation, avatar)
│   ├── jade_config/         # AI personality and configuration
│   └── Dockerfile           # Production container
├── ui/                       # React frontend
│   ├── src/components/      # UI components + 3D avatar
│   └── Dockerfile           # Production container
├── infrastructure/          # 3 deployment methods (beginner → advanced)
│   ├── method1-simple-kubectl/      # Quick kubectl deployment
│   ├── method2-terraform-localstack/ # Terraform + LocalStack
│   ├── method3-helm-argocd/         # Production GitOps
│   ├── shared-gk-policies/          # Gatekeeper runtime policies
│   └── shared-security/             # Network policies & RBAC
├── conftest-policies/       # CI/CD policy validation (OPA)
├── rag-pipeline/            # Data ingestion & ChromaDB management
├── data/
│   ├── knowledge/           # 20+ markdown source documents
│   └── chroma/              # Persistent vector database
└── docs/                    # Development documentation`}
                      </pre>
                    </div>
                  </div>
                </div>
              </div>

              {/* Chat Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <ChatPanel />
              </div>
            </div>

            {/* Right Panel - Projects */}
            <div className="space-y-6">
              {/* Projects Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <div className="mb-4">
                  <h2 className="text-gojo-primary font-semibold text-lg mb-1">
                    Current Venture
                  </h2>
                  <p className="text-gojo-secondary text-sm">
                    Developing on-premise AI solutions for enterprises with
                    strict data privacy requirements. Includes automation agents
                    that streamline repetitive processes while maintaining human
                    oversight through approval-based workflows.
                  </p>
                  <p className="text-crystal-400 text-xs mt-2 italic">
                    &ldquo;AI is not a shortcut just a multiplier of your
                    current abilities&rdquo;
                  </p>
                </div>
                <Projects />
              </div>

              {/* Quick Stats */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <h3 className="text-gojo-primary font-semibold mb-4">
                  Platform Metrics
                </h3>
                <div className="grid grid-cols-2 gap-4">
                  <div className="text-center">
                    <div className="text-2xl font-bold text-crystal-400">
                      2min
                    </div>
                    <div className="text-gojo-secondary text-sm">
                      Content Deploy
                    </div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-gold-400">
                      10min
                    </div>
                    <div className="text-gojo-secondary text-sm">
                      Full CI/CD
                    </div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-jade-400">
                      &gt;90%
                    </div>
                    <div className="text-gojo-secondary text-sm">
                      Golden Set
                    </div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-crystal-300">
                      24/7
                    </div>
                    <div className="text-gojo-secondary text-sm">
                      Availability
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Background Effects */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-crystal-500/10 rounded-full blur-3xl"></div>
        <div className="absolute bottom-1/4 right-1/4 w-64 h-64 bg-gold-500/10 rounded-full blur-2xl"></div>
      </div>
    </div>
  );
}
