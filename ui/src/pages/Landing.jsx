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

      {/* Two Column Layout */}
      <div className="relative z-10 px-6 pb-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-[55%_45%] gap-8">
            {/* Left Column - Portfolio Build (includes Sheyla chatbox) */}
            <PortfolioBuild />

            {/* Right Column - Current Venture & Projects */}
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
