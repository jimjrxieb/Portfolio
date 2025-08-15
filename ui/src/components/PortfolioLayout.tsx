import { useState } from 'react';
import { Play, MessageCircle } from 'lucide-react';
import AvatarPanel from './AvatarPanel.tsx';
import { toggleDebug } from '../debugToggle.ts';

async function askMe(message: string) {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message })
  });
  if (!res.ok) throw new Error(await res.text().catch(() => `status ${res.status}`));
  return res.json() as Promise<{ answer: string; context: string[] }>;
}

function ProjectItem({ name, active }: { name: string; active?: boolean }) {
  return (
    <div data-dev={`project-${name.replace(/\s+/g, '').toLowerCase()}`} className="flex items-center justify-between border-b border-gray-700 pb-2 mb-3">
      <span className="text-gray-100">{name}</span>
      {active && <span className="text-jade text-lg">✔</span>}
    </div>
  );
}

export default function PortfolioLayout() {
  const [avatarUrl, setAvatarUrl] = useState('/uploads/images/avatar.jpg');
  const [introUrl, setIntroUrl] = useState('/uploads/audio/intro.webm');
  const [showChat, setShowChat] = useState(false);
  const [q, setQ] = useState('');
  const [a, setA] = useState('');
  const [busy, setBusy] = useState(false);

  const playIntro = async () => {
    try {
      await new Audio(introUrl).play();
    } catch (e) {
      alert('Upload an intro first.');
    }
  };

  const handleFileUpload = async (file: File, type: 'image' | 'audio') => {
    const fd = new FormData();
    fd.append('file', file);
    try {
      const r = await fetch(`/api/upload/${type}`, { method: 'POST', body: fd });
      const d = await r.json();
      if (type === 'image') {
        setAvatarUrl(d.url);
      } else {
        setIntroUrl(d.url);
      }
    } catch (err) {
      alert('Upload failed. Please try again.');
    }
  };

  const send = async () => {
    if (!q.trim()) return;
    setBusy(true);
    setA('');
    try {
      const r = await askMe(q);
      setA(r.answer);
    } catch (e: any) {
      setA('Sorry, chat failed. Please try again.');
      console.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div 
      data-dev="portfolio-root"
      className="min-h-screen bg-ink text-white bg-ink-gradient flex flex-col items-center justify-between p-8"
    >
      {/* Header */}
      <div data-dev="header-info" className="text-center mb-8">
        <h1 className="text-3xl font-bold text-jade mb-2">Jimmie Coleman Portfolio</h1>
        <div className="space-y-1 text-sm text-gray-300">
          <p>CKA | Sec+ Certified</p>
          <p>LinkedIn: <span className="text-jade">linkedin.com/in/jimmie</span></p>
          <p>GitHub: <a href="https://github.com/jimjrxieb" className="text-jade underline hover:text-jade-light">github.com/jimjrxieb</a></p>
          <p>Afterlife: <a href="https://demo.linksmlm.com" className="text-jade underline hover:text-jade-light">demo.linksmlm.com</a></p>
        </div>
      </div>

      {/* Main Content */}
      <div data-dev="content-area" className="flex w-full max-w-5xl flex-1 items-center">
        {/* Left column - Avatar */}
        <div className="flex-1 flex flex-col items-center">
          <div className="relative mb-6">
            <img 
              src={avatarUrl}
              className="w-40 h-40 rounded-full object-cover border-4 border-jade shadow-lg jade-glow"
              onError={() => setAvatarUrl('/placeholder-avatar.png')}
              alt="Jimmie Coleman"
            />
          </div>
          
          {/* Upload controls */}
          <div data-dev="upload-controls" className="flex gap-3 mb-6">
            <label data-dev="avatar-upload" className="px-3 py-2 text-xs bg-jade/20 hover:bg-jade/30 border border-jade/50 text-jade rounded-lg cursor-pointer transition-all duration-200">
              Avatar
              <input 
                type="file" 
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) handleFileUpload(f, 'image');
                }}
              />
            </label>
            <label data-dev="intro-upload" className="px-3 py-2 text-xs bg-jade/20 hover:bg-jade/30 border border-jade/50 text-jade rounded-lg cursor-pointer transition-all duration-200">
              Intro
              <input 
                type="file" 
                accept="audio/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) handleFileUpload(f, 'audio');
                }}
              />
            </label>
          </div>

          {/* Avatar Panel with voice & talking avatar */}
          <AvatarPanel />
        </div>

        {/* Divider with subtle glow */}
        <div className="w-px bg-gradient-to-b from-transparent via-jade to-transparent h-64 mx-12 shadow-lg shadow-jade/30" data-dev="divider" />

        {/* Right column - Projects */}
        <div data-dev="projects-list" className="flex-1">
          <h2 className="text-2xl font-bold mb-6 text-jade">Projects</h2>
          <div className="space-y-4">
            <ProjectItem name="Jade @ ZRS" active />
            <ProjectItem name="Afterlife OSS" active />
            <ProjectItem name="This Portfolio" active />
          </div>
        </div>
      </div>

      {/* Footer - Chat Toggle */}
      <div data-dev="footer" className="mt-8">
        <button 
          data-dev="chat-toggle-btn"
          onClick={() => setShowChat(!showChat)}
          className="px-8 py-3 border-2 border-jade text-jade rounded-lg hover:bg-jade hover:text-black transition-all duration-200 font-medium flex items-center gap-2 hover:shadow-lg hover:shadow-jade/30"
        >
          <MessageCircle className="w-5 h-5" />
          Ask about my experience
        </button>
      </div>

      {/* Sliding Chat Panel */}
      {showChat && (
        <div 
          data-dev="chat-panel" 
          className="fixed bottom-0 left-0 right-0 bg-black/95 backdrop-blur-sm border-t-2 border-jade p-6 animate-slide-up"
        >
          <div className="max-w-4xl mx-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-jade font-bold">Chat with Jimmie</h3>
              <button 
                onClick={() => setShowChat(false)}
                className="text-jade hover:text-jade-light"
              >
                ✕
              </button>
            </div>
            
            <div className="flex gap-3 mb-4">
              <input 
                data-dev="chat-input"
                value={q} 
                onChange={(e) => setQ(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && send()}
                placeholder="Ask about my RAG/LangGraph work, Jade @ ZRS, or DevOps..." 
                className="flex-1 px-4 py-3 border border-jade/30 rounded-lg focus:ring-2 focus:ring-jade focus:border-jade bg-black/50 text-white placeholder-gray-400"
                disabled={busy}
              />
              <button 
                data-dev="send-button"
                onClick={send} 
                disabled={busy || !q.trim()} 
                className="px-6 py-3 bg-jade hover:bg-jade-light text-black rounded-lg font-medium transition-all duration-200 disabled:opacity-50"
              >
                {busy ? (
                  <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                ) : (
                  'Ask'
                )}
              </button>
            </div>
            
            <div data-dev="chat-response" className="bg-black/50 border border-jade/20 rounded-lg p-4 min-h-[120px] max-h-[300px] overflow-y-auto">
              {a ? (
                <div className="whitespace-pre-wrap text-gray-100 leading-relaxed">{a}</div>
              ) : (
                <div className="text-gray-400 italic text-center py-8">
                  Ask me anything about my current AI/ML work, enterprise automation projects, or technical background!
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Debug Toggle Button */}
      <button 
        data-dev="debug-toggle" 
        onClick={toggleDebug} 
        className="fixed bottom-3 right-3 px-3 py-1 text-xs border border-jade text-jade rounded hover:bg-jade hover:text-ink transition-colors"
      >
        DEV: Toggle outlines
      </button>

      <style jsx>{`
        @keyframes slide-up {
          from {
            transform: translateY(100%);
            opacity: 0;
          }
          to {
            transform: translateY(0);
            opacity: 1;
          }
        }
        .animate-slide-up {
          animation: slide-up 0.3s ease-out;
        }
      `}</style>
    </div>
  );
}