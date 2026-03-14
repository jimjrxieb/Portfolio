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
          <div className="bg-gradient-to-br from-jade-500/10 to-crystal-500/10 backdrop-blur-sm rounded-2xl border border-jade-500/30 p-8 text-center">
            <h2 className="text-2xl font-bold text-white mb-4">
              Platform Engineer & AI Builder
            </h2>
            <p className="text-text-secondary text-sm leading-relaxed max-w-3xl mx-auto mb-4">
              I'm a{' '}
              <span className="text-white font-medium">Platform Engineer</span> with certifications in{' '}
              <span className="text-crystal-400 font-medium">Kubernetes (CKA)</span>,{' '}
              <span className="text-crystal-400 font-medium">AWS Solutions Architect</span>, and{' '}
              <span className="text-crystal-400 font-medium">Security (CompTIA Security+)</span>.
              I build internal developer platforms, CI/CD pipelines, and policy-as-code guardrails —
              then wire AI agents into the workflow to handle the repetitive security work autonomously.
            </p>
            <p className="text-text-secondary text-sm leading-relaxed max-w-3xl mx-auto mb-4">
              This portfolio is a live example: a full-stack React app deployed via{' '}
              <span className="text-crystal-400 font-medium">ArgoCD GitOps</span> on a dedicated Linux server,
              secured by an 8-scanner CI pipeline. On the left you'll find my{' '}
              <span className="text-crystal-400 font-medium">AI & Automation</span> work, on the right my{' '}
              <span className="text-crystal-400 font-medium">Platform Engineering</span> projects, and below{' '}
              <span className="text-crystal-400 font-medium">Sheyla</span> — my AI-powered chatbox you can ask
              anything about my experience.
            </p>
          </div>
        </div>
      </div>

      {/* Two Column Layout */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-[55%_45%] gap-8">
            {/* Left Column - AI & Automation (includes Sheyla chatbox) */}
            <PortfolioBuild />

            {/* Right Column - Platform Engineering */}
            <CurrentVenture />
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
