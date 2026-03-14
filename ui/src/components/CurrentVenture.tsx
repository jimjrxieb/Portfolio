import React from 'react';

const GP_COPILOT_URL = 'https://github.com/jimjrxieb/Portfolio/tree/main/GP-copilot';
const PORTFOLIO_URL = 'https://github.com/jimjrxieb/Portfolio';


export default function CurrentVenture() {
  return (
    <div className="space-y-6">
      {/* Column Header */}
      <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
        <div className="flex items-center gap-3">
          <span className="text-2xl">🏗️</span>
          <h2 className="text-xl font-bold text-white">Platform Engineering</h2>
        </div>
      </div>

      {/* GP-Copilot Featured Card */}
      <div className="bg-gradient-to-br from-crystal-500/10 to-jade-500/10 backdrop-blur-sm rounded-2xl border border-crystal-500/30 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Featured Project</h2>
          <span className="px-2 py-1 bg-jade-500/20 text-jade-400 text-xs rounded-full border border-jade-500/30">
            Active Development
          </span>
        </div>

        <div className="mb-4">
          <h3 className="text-2xl font-bold text-crystal-400 mb-1">GP-COPILOT</h3>
          <p className="text-text-secondary text-sm">End-to-End Platform Engineering Toolkit</p>
        </div>

        <p className="text-text-secondary text-sm mb-6 leading-relaxed">
          A platform that gives platform engineers{' '}
          <span className="text-jade-400 font-medium">end-to-end security coverage</span> using
          playbooks and engagement guides. AI agents read the playbooks and execute autonomously —
          you provide oversight for the hard decisions.
        </p>

        {/* Consulting Packages */}
        <div className="mb-6">
          <h4 className="text-sm font-semibold text-white mb-4 uppercase tracking-wide">
            Consulting Packages
          </h4>

          <div className="space-y-3">
            <div className="bg-snow/5 rounded-lg p-3 border border-white/5">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-crystal-400 text-xs">01</span>
                <strong className="text-white text-xs">APP-SEC</strong>
              </div>
              <p className="text-text-secondary text-xs leading-relaxed">
                Pre-deploy code security. Runs 8 parallel scanners (Semgrep, Bandit, Trivy, gitleaks, etc.) with auto-triage and fixer scripts for Dockerfiles, Python, and web vulnerabilities.
              </p>
            </div>

            <div className="bg-snow/5 rounded-lg p-3 border border-white/5">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-crystal-400 text-xs">02</span>
                <strong className="text-white text-xs">CLUSTER-HARDENING</strong>
              </div>
              <p className="text-text-secondary text-xs leading-relaxed">
                Deploy-time Kubernetes hardening. Kyverno/OPA policies, RBAC scoping, PSS enforcement, and admission control — audit first, enforce after validation.
              </p>
            </div>

            <div className="bg-snow/5 rounded-lg p-3 border border-white/5">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-crystal-400 text-xs">03</span>
                <strong className="text-white text-xs">DEPLOY-RUNTIME</strong>
              </div>
              <p className="text-text-secondary text-xs leading-relaxed">
                Runtime security monitoring with Falco, service mesh, and distributed tracing. Detects drift, privilege escalation, and cryptomining in real time with automated incident response.
              </p>
            </div>

            <div className="bg-snow/5 rounded-lg p-3 border border-white/5">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-crystal-400 text-xs">07</span>
                <strong className="text-white text-xs">FEDRAMP-READY</strong>
              </div>
              <p className="text-text-secondary text-xs leading-relaxed">
                FedRAMP Moderate compliance automation. Maps 323 NIST 800-53 controls to infrastructure evidence, runs gap analysis, and generates SSP artifacts.
              </p>
            </div>
          </div>

          <div className="mt-3 pt-3 border-t border-white/5">
            <div className="flex items-center justify-between">
              <p className="text-text-secondary/60 text-xs font-mono">
                code → harden → deploy → comply
              </p>
              <span className="text-jade-400/60 text-[10px]">28k+ lines</span>
            </div>
          </div>
        </div>

        {/* CTA */}
        <a
          href={GP_COPILOT_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 transition-colors text-sm font-medium"
        >
          View GP-Copilot
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
          </svg>
        </a>
      </div>

      {/* Projects */}
      <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
        <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <span>🚀</span>
          <span>Projects</span>
        </h2>

        <div className="space-y-3">
          {/* Portfolio */}
          <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-medium">Portfolio</h3>
              <span className="px-2 py-0.5 bg-jade-500/20 text-jade-400 text-xs rounded-full">
                Live
              </span>
            </div>
            <p className="text-text-secondary text-xs mb-2">
              This platform. Full-stack React + FastAPI with RAG-powered AI assistant, 8-scanner CI pipeline, ArgoCD GitOps on k3s.
            </p>
            <a
              href={PORTFOLIO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-crystal-400 hover:text-crystal-300 transition-colors text-xs inline-flex items-center gap-1"
            >
              View Source
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </a>
          </div>

          {/* Anthra-Cloud */}
          <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-medium">Anthra-Cloud</h3>
              <span className="px-2 py-0.5 bg-crystal-500/20 text-crystal-400 text-xs rounded-full">
                Active
              </span>
            </div>
            <p className="text-text-secondary text-xs">
              Multi-tenant SaaS security monitoring platform. EKS, Terraform, OPA policies, and full CI/CD hardening pipeline.
            </p>
          </div>

          {/* Anthra-FedRAMP */}
          <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-medium">Anthra-FedRAMP</h3>
              <span className="px-2 py-0.5 bg-gold-500/20 text-gold-400 text-xs rounded-full">
                In Progress
              </span>
            </div>
            <p className="text-text-secondary text-xs">
              FedRAMP Moderate compliance project. 323 NIST 800-53 controls mapped to infrastructure evidence with automated gap analysis.
            </p>
          </div>
        </div>
      </div>

      {/* Platform Metrics */}
      <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
        <h3 className="text-white font-semibold mb-4">Platform Metrics</h3>
        <div className="grid grid-cols-2 gap-3">
          <div className="text-center p-3 bg-snow/5 rounded-lg">
            <div className="text-2xl font-bold text-crystal-400">2min</div>
            <div className="text-text-secondary text-xs">Content Deploy</div>
          </div>
          <div className="text-center p-3 bg-snow/5 rounded-lg">
            <div className="text-2xl font-bold text-gold-400">10min</div>
            <div className="text-text-secondary text-xs">Full CI/CD</div>
          </div>
          <div className="text-center p-3 bg-snow/5 rounded-lg">
            <div className="text-2xl font-bold text-jade-400">&lt;100ms</div>
            <div className="text-text-secondary text-xs">RAG Search</div>
          </div>
          <div className="text-center p-3 bg-snow/5 rounded-lg">
            <div className="text-2xl font-bold text-crystal-300">118</div>
            <div className="text-text-secondary text-xs">Embeddings</div>
          </div>
        </div>
      </div>
    </div>
  );
}
