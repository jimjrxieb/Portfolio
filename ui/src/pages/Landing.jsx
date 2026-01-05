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
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-crystal-400 to-jade-500 flex items-center justify-center">
                <span className="text-white font-bold text-sm">JC</span>
              </div>
              <div>
                <p className="text-gojo-primary font-semibold">Jimmie Coleman</p>
                <p className="text-crystal-400 text-xs">AI & Automation Engineer</p>
              </div>
            </div>
            <div className="flex gap-4 text-sm">
              <a
                href="https://www.linkedin.com/in/jimmie-coleman-jr-564a8a199/"
                target="_blank"
                rel="noopener noreferrer"
                className="text-crystal-400 hover:text-crystal-300 transition-colors"
              >
                LinkedIn
              </a>
              <a
                href="https://github.com/jimjrxieb"
                target="_blank"
                rel="noopener noreferrer"
                className="text-crystal-400 hover:text-crystal-300 transition-colors"
              >
                GitHub
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-8">
            {/* Left Panel - Intro, Chat, Deep Dive */}
            <div className="space-y-6">
              {/* Hero Introduction */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <h1 className="text-gojo-primary font-bold text-2xl mb-3">
                  AI Engineer & DevSecOps Specialist
                </h1>
                <p className="text-gojo-secondary leading-relaxed mb-4">
                  This portfolio embodies both skillsets: <span className="text-crystal-400 font-medium">Sheyla</span> (below)
                  demonstrates <span className="text-crystal-400">AI engineering</span>—production RAG with 2,600+ embeddings,
                  semantic search, and LLM integration. The platform itself demonstrates
                  <span className="text-jade-400"> DevSecOps</span>—CI/CD with 6-tool security scanning, 3 Kubernetes deployment
                  methods (kubectl → Terraform/LocalStack → Helm/ArgoCD), and policy-as-code enforcement.
                </p>
                <p className="text-gojo-secondary leading-relaxed mb-4">
                  <span className="text-jade-400 font-medium">Currently shipping</span>: GP-Copilot—autonomous security agents
                  achieving 70% auto-fix rates. Real enterprise clients (ZRS Management, 4,000+ property units).
                  Production Kubernetes clusters running 24/7. AWS deployments via LocalStack dev → real cloud prod.
                </p>
                <div className="flex flex-wrap gap-2">
                  <span className="px-3 py-1 bg-jade-500/20 text-jade-400 text-xs rounded-full border border-jade-500/30">CKA Certified</span>
                  <span className="px-3 py-1 bg-crystal-500/20 text-crystal-400 text-xs rounded-full border border-crystal-500/30">Security+</span>
                  <span className="px-3 py-1 bg-gold-500/20 text-gold-400 text-xs rounded-full border border-gold-500/30">AWS AI Practitioner (In Progress)</span>
                </div>
              </div>

              {/* Chat Section - Prominently Placed */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <ChatPanel />
              </div>

              {/* Deep Dive Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <div className="flex items-center gap-3 mb-4">
                  <span className="text-2xl">🔬</span>
                  <div>
                    <h2 className="text-gojo-primary font-semibold text-lg">Deep Dive: How This Was Built</h2>
                    <p className="text-crystal-400 text-sm">Production AI Portfolio Platform</p>
                  </div>
                </div>

                <p className="text-gojo-secondary text-sm mb-4">
                  Full-Stack RAG System | Enterprise DevSecOps | Policy-as-Code
                </p>

                {/* Collapsible Sections */}
                <details className="group mb-3">
                  <summary className="cursor-pointer text-gojo-primary font-medium text-sm py-2 px-3 bg-snow/10 rounded-lg hover:bg-snow/20 transition-colors list-none flex items-center justify-between">
                    <span>DevSecOps Implementation</span>
                    <span className="text-gojo-secondary group-open:rotate-180 transition-transform">▼</span>
                  </summary>
                  <div className="mt-2 p-3 bg-snow/5 rounded-lg border border-white/5">
                    <ul className="text-gojo-secondary text-xs space-y-2">
                      <li className="flex items-start gap-2">
                        <span className="text-jade-400">•</span>
                        <span><strong className="text-gojo-primary">CI/CD Pipeline:</strong> GitHub Actions with 6-tool parallel security scanning (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit)</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-jade-400">•</span>
                        <span><strong className="text-gojo-primary">Policy-as-Code:</strong> OPA/Conftest in CI (13 policies, 11 tests) + Gatekeeper runtime admission control</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-jade-400">•</span>
                        <span><strong className="text-gojo-primary">3 Deployment Methods:</strong> kubectl manifests → Terraform/LocalStack → Helm/ArgoCD (beginner to enterprise)</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-jade-400">•</span>
                        <span><strong className="text-gojo-primary">Security Hardening:</strong> Network Policies, RBAC, Pod Security Standards, non-root containers, pre-commit hooks</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-jade-400">•</span>
                        <span><strong className="text-gojo-primary">Public Access:</strong> Cloudflare Tunnel for TLS-encrypted access without exposed ports</span>
                      </li>
                    </ul>
                  </div>
                </details>

                <details className="group mb-3">
                  <summary className="cursor-pointer text-gojo-primary font-medium text-sm py-2 px-3 bg-snow/10 rounded-lg hover:bg-snow/20 transition-colors list-none flex items-center justify-between">
                    <span>AI/ML Architecture</span>
                    <span className="text-gojo-secondary group-open:rotate-180 transition-transform">▼</span>
                  </summary>
                  <div className="mt-2 p-3 bg-snow/5 rounded-lg border border-white/5">
                    <ul className="text-gojo-secondary text-xs space-y-2">
                      <li className="flex items-start gap-2">
                        <span className="text-crystal-400">•</span>
                        <span><strong className="text-gojo-primary">RAG Pipeline:</strong> ChromaDB vector database with 2,656+ embeddings from technical documentation</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-crystal-400">•</span>
                        <span><strong className="text-gojo-primary">Embeddings:</strong> Ollama nomic-embed-text for 768-dimensional local vector generation</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-crystal-400">•</span>
                        <span><strong className="text-gojo-primary">LLM:</strong> Claude API (claude-3-haiku-20240307) for production inference</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-crystal-400">•</span>
                        <span><strong className="text-gojo-primary">Backend:</strong> FastAPI async endpoints with &lt;100ms semantic search</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-crystal-400">•</span>
                        <span><strong className="text-gojo-primary">Ingestion:</strong> Intelligent chunking (1000 words, 200 overlap) with versioned collections for zero-downtime updates</span>
                      </li>
                    </ul>
                  </div>
                </details>

                <details className="group mb-3">
                  <summary className="cursor-pointer text-gojo-primary font-medium text-sm py-2 px-3 bg-snow/10 rounded-lg hover:bg-snow/20 transition-colors list-none flex items-center justify-between">
                    <span>Technology Stack</span>
                    <span className="text-gojo-secondary group-open:rotate-180 transition-transform">▼</span>
                  </summary>
                  <div className="mt-2 p-3 bg-snow/5 rounded-lg border border-white/5">
                    <div className="grid grid-cols-2 gap-4 text-xs">
                      <div>
                        <h5 className="text-crystal-400 font-medium mb-1">Backend</h5>
                        <div className="text-gojo-secondary space-y-0.5">
                          <div>• Python 3.11 + FastAPI</div>
                          <div>• ChromaDB 0.5.18+</div>
                          <div>• Claude API (Anthropic)</div>
                          <div>• Ollama embeddings</div>
                        </div>
                      </div>
                      <div>
                        <h5 className="text-crystal-400 font-medium mb-1">Frontend</h5>
                        <div className="text-gojo-secondary space-y-0.5">
                          <div>• React 18 + TypeScript</div>
                          <div>• Vite 6.4.1</div>
                          <div>• Tailwind CSS</div>
                          <div>• Nginx (production)</div>
                        </div>
                      </div>
                      <div>
                        <h5 className="text-crystal-400 font-medium mb-1">Infrastructure</h5>
                        <div className="text-gojo-secondary space-y-0.5">
                          <div>• Docker (multi-stage)</div>
                          <div>• Kubernetes</div>
                          <div>• Terraform + LocalStack</div>
                          <div>• Helm + ArgoCD</div>
                        </div>
                      </div>
                      <div>
                        <h5 className="text-crystal-400 font-medium mb-1">Security</h5>
                        <div className="text-gojo-secondary space-y-0.5">
                          <div>• OPA/Gatekeeper</div>
                          <div>• GitHub Actions CI</div>
                          <div>• Cloudflare Tunnel</div>
                          <div>• Pre-commit hooks</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </details>

                {/* Key Responsibilities Demonstrated */}
                <div className="mt-4 p-3 bg-snow/10 rounded-lg border border-white/10">
                  <h4 className="text-gojo-primary font-semibold text-sm mb-3">
                    Key Responsibilities Demonstrated
                  </h4>
                  <div className="grid grid-cols-1 gap-2 text-xs">
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">CI/CD Pipelines: GitHub Actions with 6-tool parallel security scanning</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Infrastructure-as-Code: Terraform + CloudFormation + Kubernetes manifests</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Container Orchestration: Kubernetes (CKA) with 3 deployment methods</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Security Automation: OPA/Conftest policies, Gatekeeper admission control</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">GitOps Workflows: ArgoCD automated pull-based deployments</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Cloud Security: IAM policies, encryption, network hardening, compliance</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Monitoring & Logging: Kubernetes health checks, API observability</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Cost Optimization: LocalStack for AWS testing, resource limits enforcement</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Incident Response: Production troubleshooting, root cause analysis</span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="text-jade-400">✅</span>
                      <span className="text-gojo-secondary">Documentation: Technical processes, architecture diagrams, runbooks</span>
                    </div>
                  </div>
                </div>

                {/* Repository Structure */}
                <div className="mt-4 p-3 bg-snow/10 rounded-lg border border-white/10">
                  <h4 className="text-gojo-primary font-semibold text-sm mb-3">
                    Repository Overview
                  </h4>
                  <pre className="text-gojo-secondary text-xs font-mono overflow-x-auto whitespace-pre">
{`Portfolio/
├── api/                    # FastAPI backend (RAG + Claude)
│   ├── main.py            # Async endpoints, health checks
│   ├── Dockerfile         # Multi-stage, non-root
│   └── requirements.txt
├── ui/                     # React frontend
│   ├── src/components/    # ChatPanel, Projects
│   └── Dockerfile         # Nginx production
├── infrastructure/
│   ├── method1-simple-kubectl/    # Basic K8s manifests
│   ├── method2-terraform-localstack/  # IaC + AWS mock
│   └── method3-helm-argocd/       # GitOps deployment
├── GP-copilot/             # Security automation platform
│   ├── conftest-policies/ # OPA policies (13 policies)
│   └── agents/            # K8s, OPA, GHA fix agents
├── rag-pipeline/           # Document processing
│   ├── 00-new-rag-data/   # Drop new docs here
│   ├── 02-prepared-rag-data/  # Stage 1-3 output
│   ├── 03-ingest-rag-data/    # Embed + ChromaDB
│   └── 04-processed-rag-data/ # Archive
└── .github/workflows/      # CI/CD pipeline`}
                  </pre>
                </div>

                {/* GitHub Link */}
                <div className="mt-4 pt-4 border-t border-white/10">
                  <a
                    href="https://github.com/jimjrxieb/Portfolio"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 text-sm transition-colors"
                  >
                    <span>📂</span> View Full Source on GitHub →
                  </a>
                </div>
              </div>
            </div>

            {/* Right Panel - Projects & Experience */}
            <div className="space-y-6">
              {/* Current Focus */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <div className="flex items-center gap-3 mb-4">
                  <span className="text-2xl">🎯</span>
                  <div>
                    <h2 className="text-gojo-primary font-semibold text-lg">Current Focus</h2>
                    <p className="text-gojo-secondary text-sm">LinkOps AI-BOX</p>
                  </div>
                </div>
                <p className="text-gojo-secondary text-sm leading-relaxed mb-3">
                  Developing on-premise AI solutions for enterprises with strict data privacy requirements.
                  Includes automation agents that streamline processes while maintaining human oversight
                  through approval-based workflows.
                </p>
                <p className="text-crystal-400 text-xs italic">
                  "AI is not a shortcut—just a multiplier of your current abilities"
                </p>
              </div>

              {/* GP-Copilot Flagship Project */}
              <div className="bg-gradient-to-br from-crystal-500/10 to-gold-500/10 backdrop-blur-sm rounded-2xl border border-crystal-500/20 p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">🔒</span>
                    <div>
                      <h3 className="text-gojo-primary font-semibold">GP-Copilot + JADE</h3>
                      <p className="text-crystal-400 text-xs">Autonomous Security Platform</p>
                    </div>
                  </div>
                  <span className="px-2 py-1 bg-jade-500/20 text-jade-400 text-xs rounded-full">24/7 Active</span>
                </div>
                <p className="text-gojo-secondary text-sm leading-relaxed mb-3">
                  Enterprise-grade AI security platform running autonomously in Kubernetes. JADE
                  (Junior Autonomous DevSecOps Engineer) auto-fixes Kubernetes, OPA policies, and
                  IaC issues using our fine-tuned Qwen model—<span className="text-jade-400">100% local, no cloud dependencies</span>.
                </p>
                <div className="grid grid-cols-2 gap-2 text-xs mb-3">
                  <div className="flex items-center gap-1">
                    <span className="text-jade-400">✓</span>
                    <span className="text-gojo-secondary">70% auto-fix rate</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-jade-400">✓</span>
                    <span className="text-gojo-secondary">20+ security scanners</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-jade-400">✓</span>
                    <span className="text-gojo-secondary">Per-project RAG</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-jade-400">✓</span>
                    <span className="text-gojo-secondary">HIPAA/SOC2 compliant</span>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 text-xs">
                  <span className="text-gojo-secondary">Qwen2.5-7B</span>
                  <span className="text-white/30">•</span>
                  <span className="text-gojo-secondary">ChromaDB</span>
                  <span className="text-white/30">•</span>
                  <span className="text-gojo-secondary">OPA/Gatekeeper</span>
                  <span className="text-white/30">•</span>
                  <span className="text-gojo-secondary">LangGraph</span>
                </div>
                <div className="mt-3 pt-3 border-t border-white/10">
                  <a
                    href="https://github.com/jimjrxieb/Portfolio/tree/main/GP-copilot"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 text-xs transition-colors"
                  >
                    <span>📂</span> View GP-Copilot on GitHub →
                  </a>
                </div>
              </div>

              {/* Projects Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <Projects />
              </div>

              {/* Quick Stats */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <h3 className="text-gojo-primary font-semibold mb-4">Platform Metrics</h3>
                <div className="grid grid-cols-2 gap-4">
                  <div className="text-center p-3 bg-snow/5 rounded-lg">
                    <div className="text-2xl font-bold text-crystal-400">2min</div>
                    <div className="text-gojo-secondary text-xs">Content Deploy</div>
                  </div>
                  <div className="text-center p-3 bg-snow/5 rounded-lg">
                    <div className="text-2xl font-bold text-gold-400">10min</div>
                    <div className="text-gojo-secondary text-xs">Full CI/CD</div>
                  </div>
                  <div className="text-center p-3 bg-snow/5 rounded-lg">
                    <div className="text-2xl font-bold text-jade-400">&lt;100ms</div>
                    <div className="text-gojo-secondary text-xs">RAG Search</div>
                  </div>
                  <div className="text-center p-3 bg-snow/5 rounded-lg">
                    <div className="text-2xl font-bold text-crystal-300">2,656+</div>
                    <div className="text-gojo-secondary text-xs">Embeddings</div>
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
