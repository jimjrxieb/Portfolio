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

      {/* Welcome Section - Centralized */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6 text-center">
            <h2 className="text-xl font-bold text-white mb-4">
              Welcome to My Portfolio Platform
            </h2>
            <p className="text-text-secondary text-sm leading-relaxed max-w-3xl mx-auto">
              This is my full-stack React portfolio platform built using DevSecOps best practices — from a
              secure GitHub Actions CI pipeline to ArgoCD GitOps deployment on a dedicated Linux server
              (converted from an old Windows laptop). On the left you'll find my{' '}
              <span className="text-crystal-400 font-medium">AI & Automation</span> work, and on the right
              my <span className="text-crystal-400 font-medium">Platform Engineering</span> projects.
              Below you'll also find{' '}
              <span className="text-crystal-400 font-medium">Sheyla</span>, my AI-powered chatbox where you
              can ask any question about my experience.
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
