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
