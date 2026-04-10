import Hero from '../components/Hero.tsx';
import PortfolioBuild from '../components/PortfolioBuild.tsx';
import CurrentVenture from '../components/CurrentVenture.tsx';

export default function Landing() {
  return (
    <div
      className="min-h-screen bg-gradient-to-br from-ink via-ink to-crystal-900"
      data-dev="landing"
    >
      {/* Hero Section - Full Width */}
      <Hero />

      {/* Welcome + About - Centralized */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="bg-gradient-to-br from-jade-500/10 to-crystal-500/10 backdrop-blur-sm rounded-2xl border border-jade-500/30 p-8">
            {/* Methodology header */}
            <h2 className="text-2xl font-bold text-white mb-6 text-center">
              Understand{' '}
              <span className="text-text-muted mx-1">&gt;</span> Secure{' '}
              <span className="text-text-muted mx-1">&gt;</span> Verify{' '}
              <span className="text-text-muted mx-1">&gt;</span> Optimize{' '}
              <span className="text-text-muted mx-1">=</span>{' '}
              <span className="text-jade-400">Cost &amp; Time Savings</span>
            </h2>

            {/* Paragraph 1 — Who I am */}
            <p className="text-text-secondary text-sm leading-relaxed mb-4">
              I'm a cybersecurity professional focused on{' '}
              <span className="text-white font-medium">vulnerability management</span> and{' '}
              <span className="text-white font-medium">security controls</span>. I implement NIST 800-53 controls
              mapped to OSI layers and the DevOps pipeline in a home lab — and the application I'm breaking is this
              one. This portfolio runs through a staging environment where I deliberately introduce failures, validate
              that my detective controls catch them, remediate the findings, and then promote to production with
              packaged evidence. I hold a{' '}
              <span className="text-crystal-400 font-medium">CKA</span>,{' '}
              <span className="text-crystal-400 font-medium">AWS SAA</span>,{' '}
              <span className="text-crystal-400 font-medium">Security+</span>, and an{' '}
              <span className="text-crystal-400 font-medium">active DoD Secret Clearance</span>. Everything I've
              built over the past two years has been under the guidance of{' '}
              <span className="text-white font-medium">Constant Young</span>, my mentor — his influence shapes how
              I approach every engagement and every decision. I'm currently using the lab to study for and pass my{' '}
              <span className="text-crystal-400 font-medium">CompTIA CySA+</span>.
            </p>

            {/* Paragraph 2 — Open-source philosophy */}
            <p className="text-text-secondary text-sm leading-relaxed mb-4">
              I configure open-source tools not to replace enterprise solutions, but to{' '}
              <span className="text-white font-medium">automate them and filter noise</span>. Trivy, Semgrep,
              Falco, OPA — each one is tuned to surface what matters and suppress what doesn't, so analysts spend
              time on real findings instead of duplicates. The point isn't the tool itself. Understanding{' '}
              <span className="text-crystal-400 font-medium">what the tool is supposed to prevent or provide</span>{' '}
              is what matters most. Without that understanding, you're just generating alerts nobody reads.
            </p>

            {/* Paragraph 3 — Portfolio + tooling */}
            <p className="text-text-secondary text-sm leading-relaxed mb-4">
              This portfolio site is a production app built with security and GitOps best practices end to end.
              Code pushes trigger an{' '}
              <span className="text-crystal-400 font-medium">8-scanner CI pipeline</span> in GitHub Actions,
              images deploy to a{' '}
              <span className="text-crystal-400 font-medium">k3s cluster</span> via Helm and ArgoCD,
              traffic routes through a{' '}
              <span className="text-crystal-400 font-medium">Cloudflare Tunnel</span>, and admission control
              is enforced by OPA/Gatekeeper — all managed as code. Below, you can talk to{' '}
              <span className="text-crystal-400 font-medium">Sheyla</span>, my AI portfolio assistant — ask her
              anything about my experience, projects, or certifications. She's secured following{' '}
              <span className="text-crystal-400 font-medium">NIST AI 600-1</span> with prompt injection detection,
              input sanitization, output filtering, rate limiting, and a full audit trail.
            </p>

            {/* Tool → NIST Control Family mapping */}
            <div className="mt-6">
              <h3 className="text-sm font-semibold text-text-muted uppercase tracking-wider mb-3 text-center">
                Tool → NIST 800-53 Control Family
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">SC-7, SC-8</span>
                  <span className="text-text-secondary">Cloudflare Tunnel — Boundary Protection, Transmission Confidentiality</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">RA-5, SA-11</span>
                  <span className="text-text-secondary">GitHub Actions — Vulnerability Scanning, Developer Testing</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">AC-2, AC-3, AU-2</span>
                  <span className="text-text-secondary">k3s Cluster — Access Control, Audit Events</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">CM-2, CM-6</span>
                  <span className="text-text-secondary">Helm — Baseline Configuration, Config Settings</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">CM-2, SA-10</span>
                  <span className="text-text-secondary">ArgoCD — Baseline Tracking, Developer Config Management</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">CM-2, CM-6</span>
                  <span className="text-text-secondary">Ansible — Baseline Configuration, Config Deployment</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">CM-6, CM-7, AC-6</span>
                  <span className="text-text-secondary">OPA/Gatekeeper — Config Policy, Least Functionality, Least Privilege</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-jade-500/10">
                  <span className="text-jade-400 font-mono font-bold shrink-0">SI-2, SI-3, CM-8</span>
                  <span className="text-text-secondary">Docker + Trivy — Flaw Remediation, Malware Protection, SBOM Inventory</span>
                </div>
              </div>
            </div>

            {/* Sheyla AI → NIST Control Family mapping */}
            <div className="mt-6">
              <h3 className="text-sm font-semibold text-text-muted uppercase tracking-wider mb-3 text-center">
                Sheyla AI Security → NIST 800-53 + AI 600-1
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">SI-10</span>
                  <span className="text-text-secondary">Prompt Injection Detection — Information Input Validation</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">SI-10, SC-18</span>
                  <span className="text-text-secondary">Input Sanitization — Input Validation, Mobile Code</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">SI-15</span>
                  <span className="text-text-secondary">Output Filtering — Information Output Filtering</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">SC-5, SC-7</span>
                  <span className="text-text-secondary">Rate Limiting — DoS Protection, Boundary Protection</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">AU-2, AU-3, AU-12</span>
                  <span className="text-text-secondary">Audit Trail — Audit Events, Content of Records, Record Generation</span>
                </div>
                <div className="flex items-start gap-2 px-3 py-2 rounded-lg bg-ink/40 border border-crystal-500/10">
                  <span className="text-crystal-400 font-mono font-bold shrink-0">AI 600-1</span>
                  <span className="text-text-secondary">NIST AI RMF — Governance, Mapping, Measurement, Management of AI Risk</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Two Column Layout */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-[55%_45%] gap-8">
            {/* Left Column - Platform Engineering (the core work) */}
            <CurrentVenture />

            {/* Right Column - AI & Automation (includes Sheyla chatbox) */}
            <PortfolioBuild />
          </div>
        </div>
      </div>

      {/* Background Effects */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-crystal-500/10 rounded-full blur-3xl"></div>
        <div className="absolute bottom-1/4 right-1/4 w-64 h-64 bg-jade-500/10 rounded-full blur-2xl"></div>
      </div>
    </div>
  );
}
