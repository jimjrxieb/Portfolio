import ChatPanel from './ChatPanel';

export default function PortfolioBuild() {
  return (
    <div className="space-y-6">
      {/* Sheyla Chat Box */}
      <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
        <div className="flex items-center gap-3 mb-6 pb-4 border-b border-white/10">
          <span className="text-2xl">🤖</span>
          <h2 className="text-xl font-bold text-white">AI & Automation</h2>
        </div>

        <div className="flex items-center gap-3 mb-4">
          <span className="text-2xl">💬</span>
          <div>
            <h3 className="text-white font-semibold text-lg">Talk to Sheyla</h3>
            <p className="text-crystal-400 text-sm">Ask about my experience</p>
          </div>
        </div>
        <ChatPanel />
      </div>

      {/* AI/ML Journey */}
      <div className="bg-gradient-to-br from-crystal-500/10 to-jade-500/10 backdrop-blur-sm rounded-2xl border border-crystal-500/30 p-6">
        <div className="flex items-center gap-3 mb-6 pb-4 border-b border-white/10">
          <span className="text-2xl">🧠</span>
          <h2 className="text-xl font-bold text-white">AI/ML Journey</h2>
        </div>

        <p className="text-text-secondary text-sm leading-relaxed mb-6">
          Coding with{' '}
          <span className="text-white font-medium">Claude Code</span> and{' '}
          <span className="text-white font-medium">Codex</span> shifted how I
          build security tooling. What used to be manual GRC documentation is
          now encoded as agents and runbooks — freeing bandwidth to go deeper on
          actual security controls. The CBBP methodology runs on four
          purpose-built agents:{' '}
          <span className="text-crystal-400 font-medium">comply-engineer</span>,{' '}
          <span className="text-crystal-400 font-medium">build-engineer</span>,{' '}
          <span className="text-crystal-400 font-medium">break-engineer</span>,
          and{' '}
          <span className="text-crystal-400 font-medium">prove-engineer</span> —
          each executing its phase against the target application and generating
          evidence as output. BERU gets trained on that evidence, turning real
          lab findings into a domain-specific GRC analyst model. RAG ingestion
          runs via nomic-embed-text (768-dim) into ChromaDB — 33k+ documents
          across 7 knowledge domains feed Sheyla.
        </p>

        {/* KATIE */}
        <div className="bg-snow/5 rounded-xl p-5 border border-white/5 mb-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <span className="text-lg">⚡</span>
              <h3 className="text-white font-bold text-lg">KATIE</h3>
              <span className="text-text-muted text-xs font-mono">
                LLaMA 3.2-3B
              </span>
            </div>
            <span className="px-2 py-1 bg-gold-500/20 text-gold-400 text-xs rounded-full border border-gold-500/30">
              Training — 47%
            </span>
          </div>

          <p className="text-text-secondary text-sm leading-relaxed mb-4">
            Katie is my fast-triage Kubernetes operations agent, backed by my{' '}
            <span className="text-crystal-400 font-medium">
              CKA certification
            </span>
            . She gets deployed into the cluster and runs 24/7 as the brain
            behind my <span className="text-white font-medium">k8s-gpt</span>{' '}
            and <span className="text-white font-medium">kubectl-ai</span> stack
            — classifying findings, routing decisions by E/D/C rank, and
            executing on playbooks and scripts autonomously for anything within
            her authority. CPU inference on Ollama, no GPU needed for a 3B
            model.
          </p>

          <div className="grid grid-cols-2 gap-2 mb-3">
            <div className="bg-ink/40 rounded-lg p-2.5 border border-jade-500/10">
              <div className="text-white text-xs font-medium mb-0.5">
                Training Corpus
              </div>
              <p className="text-text-secondary text-[10px]">
                42,276 curated examples (284k raw → 85% rejected by 6-gate
                quality pipeline)
              </p>
            </div>
            <div className="bg-ink/40 rounded-lg p-2.5 border border-jade-500/10">
              <div className="text-white text-xs font-medium mb-0.5">
                Architecture
              </div>
              <p className="text-text-secondary text-[10px]">
                QLoRA r=64, 4-bit quantization, cosine LR schedule, 10k-chunk
                training with fresh LoRA per chunk
              </p>
            </div>
          </div>

          <div className="flex items-center gap-4 text-xs text-text-muted">
            <span className="font-mono">2/5 chunks trained</span>
            <span>·</span>
            <span className="font-mono">20k/42k examples</span>
            <span>·</span>
            <span>Target: 60% weighted accuracy, 0 hallucinated commands</span>
          </div>
        </div>

        {/* BERU */}
        <div className="bg-snow/5 rounded-xl p-5 border border-white/5 mb-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <span className="text-lg">🔍</span>
              <h3 className="text-white font-bold text-lg">BERU</h3>
              <span className="text-text-muted text-xs font-mono">
                LLaMA 3.1-8B
              </span>
            </div>
            <span className="px-2 py-1 bg-red-500/20 text-red-400 text-xs rounded-full border border-red-500/30">
              Data Collection
            </span>
          </div>

          <p className="text-text-secondary text-sm leading-relaxed mb-4">
            Beru is being trained during my{' '}
            <span className="text-crystal-400 font-medium">CySA+ journey</span>,
            backed by my{' '}
            <span className="text-crystal-400 font-medium">Security+</span>. The
            goal is a security analyst model that takes the human POV — ingest
            findings from Nessus, GuardDuty, Prowler, and Wazuh, triage them by
            NIST 800-53 control family, score risk, and generate remediation
            summaries faster than a human analyst can. Right now I'm gathering
            real scanner data from my{' '}
            <span className="text-white font-medium">
              Anthra-SecLAB evidence folders
            </span>{' '}
            to build the training corpus. The architecture is ready — ingestion
            parser, triage engine, NIST mapper, and risk summary generator are
            built. What's blocking is real data, not code.
          </p>

          <div className="grid grid-cols-2 gap-2 mb-3">
            <div className="bg-ink/40 rounded-lg p-2.5 border border-crystal-500/10">
              <div className="text-white text-xs font-medium mb-0.5">
                Data Pipeline
              </div>
              <p className="text-text-secondary text-[10px]">
                SecLAB findings → classify_seclab_findings.py → training
                examples → eval suite expansion (20 → 400+ questions)
              </p>
            </div>
            <div className="bg-ink/40 rounded-lg p-2.5 border border-crystal-500/10">
              <div className="text-white text-xs font-medium mb-0.5">
                Modules Built
              </div>
              <p className="text-text-secondary text-[10px]">
                Ingestion parser, triage engine, NIST control mapper, risk
                summary generator, eval suite scaffold
              </p>
            </div>
          </div>

          <div className="flex items-center gap-4 text-xs text-text-muted">
            <span className="font-mono">8B params</span>
            <span>·</span>
            <span>GPU inference (vLLM)</span>
            <span>·</span>
            <span>Waiting on real scanner findings from lab</span>
          </div>
        </div>

        {/* CBBP Agent Workflow */}
        <div className="bg-snow/5 rounded-xl p-5 border border-white/5">
          <h4 className="text-white font-semibold mb-3">CBBP Agent Workflow</h4>
          <div className="space-y-1.5 text-xs font-mono">
            <div className="flex items-center gap-2">
              <span className="text-crystal-400 shrink-0 w-4 text-center">
                C
              </span>
              <span className="text-text-secondary">
                Comply — SSP authoring, control mapping, gap analysis, POA&amp;M
                baseline
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-jade-400 shrink-0 w-4 text-center">B</span>
              <span className="text-text-secondary">
                Build — SAST, container hardening, cluster policies, CI/CD gates
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-red-400 shrink-0 w-4 text-center">B</span>
              <span className="text-text-secondary">
                Break — deliberate failures, scanner runs, detective control
                validation
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-gold-400 shrink-0 w-4 text-center">P</span>
              <span className="text-text-secondary">
                Prove — remediation closures, POA&amp;M updates, auditor-ready
                evidence
              </span>
            </div>
            <div className="flex items-center gap-2 mt-1.5 pt-1.5 border-t border-white/5">
              <span className="text-text-muted shrink-0 w-4 text-center">
                &#8635;
              </span>
              <span className="text-text-muted">
                SecLAB evidence &rarr; BERU training corpus &rarr; better GRC
                triage
              </span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-white/5">
            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="bg-ink/40 rounded-lg p-2">
                <div className="text-lg font-bold text-crystal-400">4</div>
                <div className="text-text-secondary text-[10px]">
                  Phase Agents
                </div>
              </div>
              <div className="bg-ink/40 rounded-lg p-2">
                <div className="text-lg font-bold text-jade-400">33k+</div>
                <div className="text-text-secondary text-[10px]">
                  RAG Documents
                </div>
              </div>
              <div className="bg-ink/40 rounded-lg p-2">
                <div className="text-lg font-bold text-gold-400">800-53</div>
                <div className="text-text-secondary text-[10px]">
                  NIST Controls
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
