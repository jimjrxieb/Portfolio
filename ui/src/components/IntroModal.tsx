import React, { useState, useEffect } from 'react';
import { X, Shield, Sparkles } from 'lucide-react';

interface IntroModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function IntroModal({ isOpen, onClose }: IntroModalProps) {
  const [hasSeenModal, setHasSeenModal] = useState(false);

  useEffect(() => {
    const seen = localStorage.getItem('gojo-intro-seen');
    setHasSeenModal(seen === 'true');
  }, []);

  const handleClose = () => {
    localStorage.setItem('gojo-intro-seen', 'true');
    setHasSeenModal(true);
    onClose();
  };

  if (!isOpen || hasSeenModal) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-ink/80 backdrop-blur-sm"
        onClick={handleClose}
      />
      
      {/* Modal */}
      <div className="relative bg-gradient-to-br from-snow via-snow/95 to-crystal-50 rounded-2xl shadow-2xl max-w-md w-full border border-crystal-200">
        {/* Close Button */}
        <button
          onClick={handleClose}
          className="absolute top-4 right-4 p-1 rounded-full hover:bg-crystal-100 transition-colors"
        >
          <X className="w-5 h-5 text-crystal-600" />
        </button>

        {/* Content */}
        <div className="p-6 pt-8">
          <div className="text-center mb-6">
            <div className="w-16 h-16 rounded-full bg-gradient-to-r from-crystal-400 to-gold-400 flex items-center justify-center mx-auto mb-3">
              <span className="text-ink font-bold text-2xl">G</span>
            </div>
            <h2 className="text-2xl font-bold text-ink mb-2">
              Meet Gojo
            </h2>
            <p className="text-crystal-700 text-sm">
              Your AI Portfolio Assistant
            </p>
          </div>

          <div className="space-y-4">
            <div className="flex items-start gap-3 p-3 rounded-lg bg-crystal-50/50">
              <Sparkles className="w-5 h-5 text-gold-500 mt-0.5 flex-shrink-0" />
              <div>
                <h3 className="font-semibold text-ink text-sm mb-1">
                  Original Character Design
                </h3>
                <p className="text-crystal-700 text-xs leading-relaxed">
                  Gojo is an original AI assistant character inspired by anime aesthetics. 
                  The white hair and blue eyes design is our creative interpretation for this portfolio platform.
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3 p-3 rounded-lg bg-crystal-50/50">
              <Shield className="w-5 h-5 text-crystal-500 mt-0.5 flex-shrink-0" />
              <div>
                <h3 className="font-semibold text-ink text-sm mb-1">
                  Professional Portfolio Assistant
                </h3>
                <p className="text-crystal-700 text-xs leading-relaxed">
                  Ask about Jimmie's DevSecOps experience, LinkOps AI-BOX project, 
                  or technical expertise in CI/CD, Kubernetes, and AI automation.
                </p>
              </div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-crystal-200">
            <button
              onClick={handleClose}
              className="w-full bg-gradient-to-r from-crystal-500 to-gold-500 text-white px-4 py-2 rounded-lg font-medium hover:from-crystal-600 hover:to-gold-600 transition-all"
            >
              Start Conversation
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}