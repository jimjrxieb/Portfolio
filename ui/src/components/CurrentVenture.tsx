import React, { useState } from 'react';

const GP_COPILOT_URL = 'https://github.com/jimjrxieb/GP-copilot';
const SECLAB_URL = 'https://github.com/jimjrxieb/Anthra-SecLAB';
const PORTFOLIO_URL = 'https://github.com/jimjrxieb/Portfolio';
const PORTFOLIO_LIVE_URL = 'https://linksmlm.com';

export default function CurrentVenture() {
  const [packagesExpanded, setPackagesExpanded] = useState(false);
  const [seclabExpanded, setSecLabExpanded] = useState(false);
  const [portfolioExpanded, setPortfolioExpanded] = useState(false);

  return (
    <div className="space-y-6">
      {/* Anthra-SecLAB Card */}
      <div className="bg-gradient-to-br from-red-500/10 to-crystal-500/10 backdrop-blur-sm rounded-2xl border border-red-500/30 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Security Lab</h2>
          <span className="px-2 py-1 bg-red-500/20 text-red-400 text-xs rounded-full border border-red-500/30">
            Cybersecurity Analyst
          </span>
        </div>

        <div className="mb-4">
          <h3 className="text-2xl font-bold text-red-400 mb-1">
            ANTHRA-SECLAB
          </h3>
          <p className="text-text-secondary text-sm">
            Hands-on security lab for NIST 800-53 control validation across all
            7 OSI layers
          </p>
        </div>

        <p className="text-text-secondary text-sm mb-6 leading-relaxed">
          This is the lab I use to validate{' '}
          <span className="text-white font-medium">NIST 800-53 controls</span>{' '}
          against live target applications using the{' '}
          <span className="text-white font-medium">CBBP methodology</span> —
          Comply, Build, Break, Prove. Four phase agents execute each cycle
          using{' '}
          <span className="text-crystal-400 font-medium">Claude Code</span> and{' '}
          <span className="text-crystal-400 font-medium">Codex</span>,
          generating auditor-ready evidence as output. The SOC stack — Falco,
          Prometheus, Grafana, Kyverno, Fluent Bit, and Splunk — provides the
          detective controls I validate each break scenario against.
        </p>

        {/* SecLAB Packages */}
        <div className="mb-6">
          <button
            onClick={() => setSecLabExpanded(!seclabExpanded)}
            className="w-full flex items-center justify-between mb-4 group"
          >
            <h4 className="text-sm font-semibold text-white uppercase tracking-wide">
              OSI-Model Security Layers
            </h4>
            <div className="flex items-center gap-2">
              <span className="text-text-muted text-xs">
                {seclabExpanded ? 'Hide' : '7 layers'}
              </span>
              <svg
                className={`w-4 h-4 text-text-muted transition-transform duration-200 ${seclabExpanded ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </div>
          </button>

          {seclabExpanded && (
            <>
              <div className="space-y-2 mb-3">
                {[
                  {
                    num: 'L1',
                    name: 'PHYSICAL',
                    controls: 'PE-1, PE-2, PE-3, PE-6',
                    desc: 'Physical access controls, environmental monitoring, asset inventory via Snipe-IT',
                    color: 'red',
                  },
                  {
                    num: 'L2',
                    name: 'DATA LINK',
                    controls: 'SC-7, AC-3, SI-4',
                    desc: 'MAC security, ARP protection, VLAN segmentation, 802.1X — Wireshark, arpwatch',
                    color: 'red',
                  },
                  {
                    num: 'L3',
                    name: 'NETWORK',
                    controls: 'SC-7, AC-4, SI-3',
                    desc: 'Firewalls, routing, IDS/IPS, network segmentation — Suricata, Nmap, pfSense',
                    color: 'gold',
                  },
                  {
                    num: 'L4',
                    name: 'TRANSPORT',
                    controls: 'SC-8, SC-23, IA-5',
                    desc: 'TLS configuration, port security, certificate management — OpenSSL, testssl.sh',
                    color: 'gold',
                  },
                  {
                    num: 'L5',
                    name: 'SESSION',
                    controls: 'AC-12, SC-23, IA-2',
                    desc: 'Session management, token handling, session termination — Burp Suite, OWASP ZAP',
                    color: 'crystal',
                  },
                  {
                    num: 'L6',
                    name: 'PRESENTATION',
                    controls: 'SC-28, SI-10, SC-13',
                    desc: 'Encryption at rest, I/O validation, encoding analysis — BitLocker, CyberChef',
                    color: 'crystal',
                  },
                  {
                    num: 'L7',
                    name: 'APPLICATION',
                    controls: 'SA-11, RA-5, AC-6, AU-2',
                    desc: 'SAST/DAST, input validation, audit logging — Semgrep, OWASP ZAP, Splunk, Sentinel',
                    color: 'jade',
                  },
                ].map(layer => (
                  <div
                    key={layer.num}
                    className="bg-snow/5 rounded-lg p-2.5 border border-white/5"
                  >
                    <div className="flex items-center gap-2 mb-0.5">
                      <span
                        className={`text-${layer.color}-400 text-xs font-mono font-bold`}
                      >
                        {layer.num}
                      </span>
                      <strong className="text-white text-xs">
                        {layer.name}
                      </strong>
                      <span className="text-text-muted text-[10px] ml-auto font-mono">
                        {layer.controls}
                      </span>
                    </div>
                    <p className="text-text-secondary text-xs leading-relaxed">
                      {layer.desc}
                    </p>
                  </div>
                ))}
              </div>

              <div className="space-y-2 mb-3">
                <h4 className="text-xs font-semibold text-white uppercase tracking-wide">
                  Lab Environment
                </h4>
                <div className="grid grid-cols-2 gap-2">
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <div className="text-white text-xs font-medium mb-0.5">
                      SOC Stack
                    </div>
                    <p className="text-text-secondary text-[10px]">
                      Falco, Prometheus, Grafana, Kyverno, Fluent Bit, Splunk
                    </p>
                  </div>
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <div className="text-white text-xs font-medium mb-0.5">
                      Break/Fix Scenarios
                    </div>
                    <p className="text-text-secondary text-[10px]">
                      14 OSI scenarios + 3 top-level (SC-7, AC-6, CM-7)
                    </p>
                  </div>
                </div>
              </div>

              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center justify-between">
                  <p className="text-text-secondary/60 text-xs font-mono">
                    break → detect → fix → evidence
                  </p>
                  <span className="text-red-400/60 text-[10px]">
                    29 playbooks · 62 scripts · 30+ tools
                  </span>
                </div>
              </div>
            </>
          )}
        </div>

        {/* CTA */}
        <a
          href={SECLAB_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 text-red-400 hover:text-red-300 transition-colors text-sm font-medium"
        >
          View Anthra-SecLAB
          <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M17 8l4 4m0 0l-4 4m4-4H3"
            />
          </svg>
        </a>
      </div>

      {/* GP-COPILOT Featured Card */}
      <div className="bg-gradient-to-br from-crystal-500/10 to-jade-500/10 backdrop-blur-sm rounded-2xl border border-crystal-500/30 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Featured Project</h2>
          <span className="px-2 py-1 bg-crystal-500/20 text-crystal-400 text-xs rounded-full border border-crystal-500/30">
            IT Security & Compliance
          </span>
        </div>

        <div className="mb-4">
          <h3 className="text-2xl font-bold text-crystal-400 mb-1">
            GP-COPILOT
          </h3>
          <p className="text-text-secondary text-sm">
            Open-source MSSP engagement framework — CBBP methodology, 4 phase
            agents, 5 C&apos;s coverage
          </p>
        </div>

        <p className="text-text-secondary text-sm mb-6 leading-relaxed">
          Encodes what GuidePoint, Deloitte, and PwC do manually into{' '}
          <span className="text-jade-400 font-medium">
            runbooks, automation, and agents
          </span>
          . Every engagement runs the same CBBP loop: start with the SSP and
          control mapping, harden what&apos;s broken, break it deliberately to
          prove the controls catch it, then package the evidence for an auditor.
          Built with <span className="text-white font-medium">Claude Code</span>{' '}
          and <span className="text-white font-medium">Codex</span> — AI coding
          tools that made it possible to encode the entire methodology as
          executable agents instead of static documentation.
        </p>

        {/* CBBP Phases */}
        <div className="mb-6">
          <button
            onClick={() => setPackagesExpanded(!packagesExpanded)}
            className="w-full flex items-center justify-between mb-4 group"
          >
            <h4 className="text-sm font-semibold text-white uppercase tracking-wide">
              CBBP{' '}
              <span className="text-text-muted font-normal normal-case">
                (Comply &rarr; Build &rarr; Break &rarr; Prove)
              </span>{' '}
              Phases
            </h4>
            <div className="flex items-center gap-2">
              <span className="text-text-muted text-xs">
                {packagesExpanded ? 'Hide' : '4 phases'}
              </span>
              <svg
                className={`w-4 h-4 text-text-muted transition-transform duration-200 ${packagesExpanded ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </div>
          </button>

          {packagesExpanded && (
            <>
              {/* Comply */}
              <div className="mb-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-crystal-400" />
                  <span className="text-crystal-400 text-[10px] font-semibold uppercase tracking-wider">
                    Comply
                  </span>
                </div>
                <div className="space-y-2 ml-3 border-l border-crystal-400/20 pl-3">
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <p className="text-text-secondary text-xs leading-relaxed">
                      SSP authoring, NIST 800-53 control mapping, gap analysis,
                      POA&amp;M tracking. Establish the control baseline before
                      touching anything.
                    </p>
                  </div>
                </div>
              </div>

              {/* Build */}
              <div className="mb-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-jade-400" />
                  <span className="text-jade-400 text-[10px] font-semibold uppercase tracking-wider">
                    Build
                  </span>
                </div>
                <div className="space-y-2 ml-3 border-l border-jade-400/20 pl-3">
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <p className="text-text-secondary text-xs leading-relaxed">
                      Harden the application — SAST, dependency scanning,
                      container security, cluster policies, CI/CD gates. Fix
                      what the comply phase identified.
                    </p>
                  </div>
                </div>
              </div>

              {/* Break */}
              <div className="mb-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-red-400" />
                  <span className="text-red-400 text-[10px] font-semibold uppercase tracking-wider">
                    Break
                  </span>
                </div>
                <div className="space-y-2 ml-3 border-l border-red-400/20 pl-3">
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <p className="text-text-secondary text-xs leading-relaxed">
                      Deliberately introduce failures — misconfigurations,
                      exposed endpoints, weak controls — and validate that the
                      detective controls catch them.
                    </p>
                  </div>
                </div>
              </div>

              {/* Prove */}
              <div className="mb-3">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-gold-400" />
                  <span className="text-gold-400 text-[10px] font-semibold uppercase tracking-wider">
                    Prove
                  </span>
                </div>
                <div className="space-y-2 ml-3 border-l border-gold-400/20 pl-3">
                  <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                    <p className="text-text-secondary text-xs leading-relaxed">
                      Package the evidence — remediation closures, POA&amp;M
                      updates, control satisfaction artifacts. Output is
                      auditor-ready, not a slide deck.
                    </p>
                  </div>
                </div>
              </div>

              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center justify-between">
                  <p className="text-text-secondary/60 text-xs font-mono">
                    comply &rarr; build &rarr; break &rarr; prove
                  </p>
                  <span className="text-crystal-400/60 text-[10px]">
                    4 agents · 5 C&apos;s · NIST 800-53
                  </span>
                </div>
              </div>
            </>
          )}
        </div>

        {/* CTA */}
        <a
          href={GP_COPILOT_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 transition-colors text-sm font-medium"
        >
          View GP-Copilot
          <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M17 8l4 4m0 0l-4 4m4-4H3"
            />
          </svg>
        </a>
      </div>

      {/* Portfolio Production Card */}
      <div className="bg-gradient-to-br from-jade-500/10 to-crystal-500/10 backdrop-blur-sm rounded-2xl border border-jade-500/30 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Production App</h2>
          <span className="px-2 py-1 bg-jade-500/20 text-jade-400 text-xs rounded-full border border-jade-500/30">
            Live
          </span>
        </div>

        <div className="mb-4">
          <h3 className="text-2xl font-bold text-jade-400 mb-1">PORTFOLIO</h3>
          <p className="text-text-secondary text-sm">
            <a
              href={PORTFOLIO_LIVE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-crystal-400 hover:text-crystal-300 transition-colors"
            >
              linksmlm.com
            </a>{' '}
            — full-stack RAG app deployed with security and GitOps best
            practices
          </p>
        </div>

        <p className="text-text-secondary text-sm mb-4 leading-relaxed">
          A production React + FastAPI application serving as proof that the
          playbooks and controls I build actually work in a live environment.
          Code pushes flow through an{' '}
          <span className="text-white font-medium">8-scanner CI pipeline</span>{' '}
          in GitHub Actions, images deploy to a{' '}
          <span className="text-white font-medium">k3s cluster</span> via Helm
          and ArgoCD with automated sync and self-heal, traffic routes through a
          Cloudflare Tunnel, and admission control is enforced by
          OPA/Gatekeeper.
        </p>

        {/* RAG + Sheyla details */}
        <div className="mb-6">
          <button
            onClick={() => setPortfolioExpanded(!portfolioExpanded)}
            className="w-full flex items-center justify-between mb-4 group"
          >
            <h4 className="text-sm font-semibold text-white uppercase tracking-wide">
              RAG Pipeline + Sheyla AI
            </h4>
            <div className="flex items-center gap-2">
              <span className="text-text-muted text-xs">
                {portfolioExpanded ? 'Hide' : 'Details'}
              </span>
              <svg
                className={`w-4 h-4 text-text-muted transition-transform duration-200 ${portfolioExpanded ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </div>
          </button>

          {portfolioExpanded && (
            <>
              <div className="space-y-2 mb-3">
                <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                  <div className="text-white text-xs font-medium mb-1">
                    RAG Pipeline
                  </div>
                  <p className="text-text-secondary text-xs leading-relaxed">
                    A 2-stage pipeline — raw documents are sanitized,
                    semantically chunked (512 tokens via LangChain),
                    deduplicated, then embedded using Ollama's nomic-embed-text
                    (768-dim) and stored in ChromaDB. 40+ knowledge documents
                    covering my experience, projects, security implementations,
                    and architecture patterns feed Sheyla's responses.
                  </p>
                </div>
                <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                  <div className="text-white text-xs font-medium mb-1">
                    Sheyla — AI Portfolio Assistant
                  </div>
                  <p className="text-text-secondary text-xs leading-relaxed">
                    Sheyla answers questions about my experience grounded in RAG
                    context, not hallucination. She runs through a 5-layer
                    security stack mapped to OWASP LLM Top 10 + NIST AI RMF:
                    prompt injection detection (14 regex patterns), input
                    sanitization, output filtering (PII/path redaction), rate
                    limiting (10 req/min), and JSONL audit logging with hashed
                    IPs. Primary LLM is Claude with a local HuggingFace
                    fallback.
                  </p>
                </div>
                <div className="bg-snow/5 rounded-lg p-2.5 border border-white/5">
                  <div className="text-white text-xs font-medium mb-1">
                    Pipeline Flow
                  </div>
                  <p className="text-text-secondary text-xs leading-relaxed font-mono text-[10px]">
                    docs → prepare (chunk + dedup) → embed (Ollama) → ChromaDB →
                    Sheyla query → top-3 retrieval → Claude → 5-layer security →
                    response
                  </p>
                </div>
              </div>

              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center justify-between">
                  <p className="text-text-secondary/60 text-xs font-mono">
                    react · fastapi · chromadb · ollama · claude
                  </p>
                  <span className="text-jade-400/60 text-[10px]">
                    40+ docs · 768-dim vectors
                  </span>
                </div>
              </div>
            </>
          )}
        </div>

        {/* CTAs */}
        <div className="flex items-center gap-4">
          <a
            href={PORTFOLIO_LIVE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 text-jade-400 hover:text-jade-300 transition-colors text-sm font-medium"
          >
            Visit linksmlm.com
            <svg
              className="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M17 8l4 4m0 0l-4 4m4-4H3"
              />
            </svg>
          </a>
          <a
            href={PORTFOLIO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 transition-colors text-sm font-medium"
          >
            View Source
            <svg
              className="w-3 h-3"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
              />
            </svg>
          </a>
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
            <div className="text-2xl font-bold text-crystal-300">2,656+</div>
            <div className="text-text-secondary text-xs">RAG Vectors</div>
          </div>
        </div>
      </div>
    </div>
  );
}
