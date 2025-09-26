import { useState, useEffect } from 'react';
import ChatPanel from '../components/ChatPanel.tsx';
import Projects from '../components/Projects.tsx';

export default function Landing() {
  const [showIntroModal, setShowIntroModal] = useState(false);

  useEffect(() => {
    const hasSeenIntro = localStorage.getItem('gojo-intro-seen');
    if (!hasSeenIntro) {
      setShowIntroModal(true);
    }
  }, []);
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
                      href="https://linkedin.com/in/jimmie-coleman"
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
                  <h3 className="text-gojo-primary font-semibold mb-3">
                    **DevSecOps Engineer | AI Systems Implementation**
                  </h3>
                  <p className="text-gojo-secondary text-sm leading-relaxed mb-4">
                    CKA & CompTIA Security+ certified with production experience
                    in containerized AI systems. This portfolio demonstrates
                    practical implementation across three areas:
                  </p>

                  <ul className="text-gojo-secondary text-sm leading-relaxed space-y-2 mb-4">
                    <li>
                      <strong className="text-gojo-primary">
                        DevSecOps Automation
                      </strong>{' '}
                      - GitHub Actions CI/CD pipeline with ArgoCD deployment and
                      integrated security scanning
                    </li>
                    <li>
                      <strong className="text-gojo-primary">
                        RAG Document Processing
                      </strong>{' '}
                      - Vector embeddings and semantic search for enterprise
                      document analysis using ChromaDB and sentence transformers
                    </li>
                    <li>
                      <strong className="text-gojo-primary">
                        Production AI Deployment
                      </strong>{' '}
                      - Containerized chatbot systems with Docker/Kubernetes,
                      implementing retrieval-augmented generation for business
                      document queries
                    </li>
                  </ul>

                  <p className="text-gojo-secondary text-sm leading-relaxed mb-3">
                    The Jade chatbot showcases end-to-end RAG implementation:
                    document chunking, vector storage, semantic search, and LLM
                    response generation. Built for real enterprise use cases
                    with proper error handling and caching.
                  </p>

                  <p className="text-crystal-400 text-sm font-medium">
                    <strong>Technical stack:</strong> Python, Docker,
                    Kubernetes, ChromaDB, OpenAI APIs, sentence-transformers
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

      {/* IP-Safe Intro Modal */}
      {showIntroModal && (
        <div className="text-center text-yellow-400 p-4">
          Intro Modal Placeholder
        </div>
      )}
    </div>
  );
}
