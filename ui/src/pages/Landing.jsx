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
                    <strong className="text-gojo-primary">DevSecOps Implementation:</strong> This portfolio&apos;s infrastructure demonstrates enterprise-grade security automation throughout the entire CI/CD lifecycle. GitHub Actions orchestrates six parallel security scanners (detect-secrets, Semgrep, Trivy, Bandit, Safety, npm audit) before any deployment. Policy-as-Code enforcement runs at two layers: OPA/Conftest validates 150+ security rules in CI, while Gatekeeper provides runtime admission control in Kubernetes. The platform showcases three progressive deployment methods—simple kubectl manifests for rapid prototyping, Terraform with LocalStack for AWS simulation, and production Helm charts with ArgoCD GitOps for automated deployments. Container security is hardened with multi-stage Docker builds, non-root users, dropped capabilities, and Pod Security Standards. Network security implements zero-trust principles through Kubernetes Network Policies restricting pod-to-pod traffic, RBAC for least-privilege access, and Cloudflare Tunnel for TLS-encrypted public access without exposing ports.
                  </p>
                  <p className="text-gojo-secondary text-xs leading-relaxed mb-4">
                    <strong className="text-gojo-primary">AI/ML Engineering:</strong> The chat interface you&apos;re using right now is powered by a production RAG pipeline processing real-time semantic search across 2,656+ vector embeddings. When you ask a question, the FastAPI backend queries ChromaDB&apos;s vector database (using Ollama&apos;s nomic-embed-text for 768-dimensional embeddings) to retrieve relevant context from comprehensive technical documentation covering DevSecOps practices, project architecture, and deployment methods. The system then constructs a prompt with source citations and sends it to Claude API (Anthropic&apos;s claude-3-haiku-20240307 model) for natural language generation, returning responses with relevance scores in under 100ms. The ingestion pipeline demonstrates practical ML engineering: markdown documents are sanitized, intelligently chunked (1000 words with 200-word overlap for context preservation), embedded via Ollama, and stored in versioned ChromaDB collections supporting atomic swaps for zero-downtime knowledge base updates. This architecture showcases the complete ML lifecycle from data processing to production inference.
                  </p>

                  <div className="space-y-3 text-sm">
                    <div className="bg-snow/5 rounded p-3">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-lg">🧠</span>
                        <strong className="text-gojo-primary">AI/RAG Stack</strong>
                      </div>
                      <ul className="text-gojo-secondary text-xs space-y-1 ml-7">
                        <li>• ChromaDB (2,656+ vectors) + Ollama embeddings</li>
                        <li>• Claude API (Anthropic) for production LLM</li>
                        <li>• FastAPI backend with semantic search &lt;100ms</li>
                        <li>• React/Vite frontend with real-time chat</li>
                      </ul>
                    </div>

                    <div className="bg-snow/5 rounded p-3">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-lg">🔒</span>
                        <strong className="text-gojo-primary">Security & Policy</strong>
                      </div>
                      <ul className="text-gojo-secondary text-xs space-y-1 ml-7">
                        <li>• OPA/Conftest CI/CD policy validation (150+ tests)</li>
                        <li>• Gatekeeper runtime admission control</li>
                        <li>• Network policies + RBAC + Pod Security Standards</li>
                        <li>• 6-tool security pipeline: detect-secrets, Semgrep, Trivy, Bandit, Safety, npm</li>
                      </ul>
                    </div>

                    <div className="bg-snow/5 rounded p-3">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-lg">☁️</span>
                        <strong className="text-gojo-primary">Infrastructure & CI/CD</strong>
                      </div>
                      <ul className="text-gojo-secondary text-xs space-y-1 ml-7">
                        <li>• Kubernetes (3 deployment methods: kubectl → Terraform → Helm+ArgoCD)</li>
                        <li>• GitHub Actions: parallel security scans → build → deploy</li>
                        <li>• Cloudflare Tunnel for secure public access</li>
                        <li>• Docker multi-stage builds, non-root containers</li>
                      </ul>
                    </div>
                  </div>

                  <p className="text-crystal-400 text-xs font-medium mt-4">
                    <strong>Tech Stack:</strong> Python, TypeScript, React, FastAPI, ChromaDB, Ollama, Claude, Kubernetes, OPA/Rego, GitHub Actions, Cloudflare
                  </p>
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
