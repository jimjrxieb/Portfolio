import { useState, useEffect } from 'react';
import AvatarPanel from '../components/AvatarPanel.tsx';
import ChatPanel from '../components/ChatPanel.tsx';
import Projects from '../components/Projects.tsx';
// import IntroModal from '../components/IntroModal.tsx';

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
            {/* Left Panel - Avatar & Chat */}
            <div className="space-y-6">
              {/* Avatar Section */}
              <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
                <div className="mb-4">
                  <h1 className="text-gojo-primary font-bold text-2xl mb-2">
                    Jimmie Coleman Portfolio
                  </h1>
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
                <AvatarPanel />
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
                    Revolutionary AI solutions with security-first approach
                  </p>
                  <p className="text-crystal-400 text-xs mt-2 italic">
                    "AI is not a shortcut just a multiplier of your current abilities"
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
