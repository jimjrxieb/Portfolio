import React from 'react';

const GP_COPILOT_URL = 'https://github.com/jimjrxieb/Portfolio/tree/main/GP-copilot';
const PORTFOLIO_URL = 'https://github.com/jimjrxieb/Portfolio';

interface RankLevel {
  label: string;
  action: string;
  percent: string;
  color: 'green' | 'yellow' | 'red';
}

const rankLevels: RankLevel[] = [
  { label: 'E/D-Rank', action: 'Auto-handled', percent: '80%', color: 'green' },
  { label: 'C-Rank', action: 'Quick approval', percent: '15%', color: 'yellow' },
  { label: 'B/S-Rank', action: 'Human expertise', percent: '5%', color: 'red' },
];

function getRankBarWidth(percent: string): string {
  const num = parseInt(percent);
  return `${num}%`;
}

function getRankColor(color: 'green' | 'yellow' | 'red'): string {
  switch (color) {
    case 'green':
      return 'bg-jade-500';
    case 'yellow':
      return 'bg-gold-500';
    case 'red':
      return 'bg-red-500';
  }
}

export default function CurrentVenture() {
  return (
    <div className="space-y-6">
      {/* Current Focus - LinkOps AI-BOX */}
      <div className="bg-gradient-to-br from-jade-500/10 to-crystal-500/10 backdrop-blur-sm rounded-2xl border border-jade-500/30 p-6">
        <div className="flex items-center gap-3 mb-4">
          <span className="text-2xl">🎯</span>
          <h2 className="text-xl font-bold text-white">Current Focus</h2>
        </div>
        <h3 className="text-2xl font-bold text-jade-400 mb-3">LinkOps AI-BOX</h3>
        <p className="text-text-secondary text-sm leading-relaxed mb-4">
          I'm an aspiring <span className="text-white font-medium">AI & Automation Engineer</span> with
          certifications in <span className="text-crystal-400 font-medium">Kubernetes (CKA)</span> and{' '}
          <span className="text-crystal-400 font-medium">Security (CompTIA Security+)</span>. My focus is
          production-grade RAG systems, policy-as-code, and enterprise DevSecOps pipelines.
        </p>
        <p className="text-text-secondary text-sm leading-relaxed">
          My first major project is creating a platform with agentic AI that can secure the entire DevSecOps
          process — automation agents that streamline workflows while maintaining human oversight through
          approval-based systems.
        </p>
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
          <p className="text-text-secondary text-sm">Cloud Security Automation Platform</p>
        </div>

        <p className="text-text-secondary text-sm mb-6 leading-relaxed">
          What if you had <span className="text-jade-400 font-medium">30 DevSecOps engineers</span> working 24/7,
          never sleeping, never missing a vulnerability?
        </p>

        {/* Iron Legion Section */}
        <div className="mb-6">
          <h4 className="text-sm font-semibold text-white mb-4 uppercase tracking-wide">
            The Iron Legion for Cloud Security
          </h4>

          <div className="space-y-4">
            {/* JADE */}
            <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">🧠</span>
                <div>
                  <span className="text-crystal-400 font-bold">JADE</span>
                  <span className="text-text-secondary text-sm ml-2">— The Brain</span>
                </div>
              </div>
              <p className="text-text-secondary text-xs leading-relaxed">
                Fine-tuned security LLM trained on 800k examples. Knows when to act alone and when to call for backup.
              </p>
            </div>

            {/* JSA */}
            <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">🦾</span>
                <div>
                  <span className="text-jade-400 font-bold">JSA</span>
                  <span className="text-text-secondary text-sm ml-2">— The Legion</span>
                </div>
              </div>
              <p className="text-text-secondary text-xs mb-3">
                Autonomous agents deployed across your infrastructure:
              </p>
              <ul className="text-xs space-y-1 text-text-secondary">
                <li className="flex items-center gap-2">
                  <span className="text-crystal-400">→</span>
                  <span><strong className="text-white">JSA-CI</strong> Guards every pipeline</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-crystal-400">→</span>
                  <span><strong className="text-white">JSA-DEVSECOPS</strong> Patrols every namespace</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-crystal-400">→</span>
                  <span><strong className="text-white">JSA-MONITOR</strong> Watches for threats</span>
                </li>
              </ul>
              <p className="text-text-secondary/70 text-xs mt-3 italic">
                Scale to 100 agents. They scan, analyze, fix — while you sleep.
              </p>
            </div>
          </div>
        </div>

        {/* ML Rank System */}
        <div className="mb-6">
          <h4 className="text-sm font-semibold text-white mb-3 uppercase tracking-wide">
            ML-Powered Rank System
          </h4>
          <p className="text-text-secondary text-xs mb-3">
            sklearn + XGBoost determine what agents handle alone
          </p>
          <div className="space-y-2">
            {rankLevels.map((rank) => (
              <div key={rank.label} className="flex items-center gap-3">
                <div className="w-20 text-xs text-text-secondary">{rank.label}</div>
                <div className="flex-1 h-2 bg-snow/10 rounded-full overflow-hidden">
                  <div
                    className={`h-full ${getRankColor(rank.color)} rounded-full`}
                    style={{ width: getRankBarWidth(rank.percent) }}
                  />
                </div>
                <div className="w-24 text-xs text-text-secondary text-right">
                  {rank.percent} {rank.action}
                </div>
              </div>
            ))}
          </div>
          <p className="text-jade-400 text-xs mt-3 font-medium">
            One engineer manages 10x more infrastructure
          </p>
        </div>

        {/* Consulting */}
        <div className="bg-snow/5 rounded-lg p-3 mb-4 border border-white/5">
          <h5 className="text-xs font-semibold text-white mb-1 uppercase tracking-wide">
            Built for Consulting
          </h5>
          <p className="text-text-secondary text-xs">
            Multi-tenant. Each client gets their own security legion. You provide oversight for the hard stuff.
          </p>
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

      {/* Other Projects */}
      <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
        <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <span>🚀</span>
          <span>Other Projects</span>
        </h2>

        <div className="space-y-3">
          {/* AI Interview Platform */}
          <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-medium">AI Interview Platform</h3>
              <span className="px-2 py-0.5 bg-jade-500/20 text-jade-400 text-xs rounded-full">
                Deployed
              </span>
            </div>
            <p className="text-text-secondary text-xs">
              Secure cloud architecture with AWS. Real-time AI-powered mock interviews.
            </p>
          </div>

          {/* This Portfolio */}
          <div className="bg-snow/5 rounded-lg p-4 border border-white/5">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-white font-medium">This Portfolio</h3>
              <span className="px-2 py-0.5 bg-crystal-500/20 text-crystal-400 text-xs rounded-full">
                Active
              </span>
            </div>
            <p className="text-text-secondary text-xs mb-2">
              The platform you're viewing now. Full-stack RAG + DevSecOps showcase.
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
            <div className="text-text-secondary text-xs">Embeddings</div>
          </div>
        </div>
      </div>
    </div>
  );
}
