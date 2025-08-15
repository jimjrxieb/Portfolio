import { useState } from 'react';
import AvatarPanel from './AvatarPanel.tsx';

async function askMe(message: string) {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message })
  });
  if (!res.ok) throw new Error(await res.text().catch(() => `status ${res.status}`));
  return res.json() as Promise<{ answer: string; context: string[] }>;
}

// data-dev:ui-intro-snippets
const suggestedQuestions = [
  "What AI/ML work are you focused on?",
  "Tell me about the Jade project",
  "What's your current DevOps pipeline?", 
  "How does your RAG system work?"
];

// data-dev:ui-voice-presets
const VOICE_PRESETS = [
  { id: "default", label: "Default Voice (Env)" },
  { id: "giancarlo", label: "Giancarlo Esposito Style" },
];

export default function TwoPanelHome() {
  const [avatarUrl, setAvatarUrl] = useState('/uploads/images/avatar.jpg');
  const [introUrl, setIntroUrl] = useState('/uploads/audio/intro.webm');
  const [q, setQ] = useState('');
  const [a, setA] = useState('');
  const [busy, setBusy] = useState(false);
  const [selectedVoice, setSelectedVoice] = useState('default');

  const playIntro = async () => {
    try {
      await new Audio(introUrl).play();
    } catch (e) {
      alert('Upload an intro first.');
    }
  };

  const send = async (question?: string) => {
    const message = question || q;
    if (!message.trim()) return;
    setQ(question || q);
    setBusy(true);
    setA('');
    try {
      const r = await askMe(message);
      setA(r.answer);
    } catch (e: any) {
      setA('Sorry, chat failed.');
      console.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div data-dev="portfolio-root" className="min-h-screen bg-ink text-white bg-ink-gradient">
      <div className="container mx-auto p-6">
        <header className="text-center mb-8">
          <h1 data-dev="header-info" className="text-4xl font-bold text-jade mb-2">Jimmie Coleman</h1>
          <p className="text-xl text-jade-light mb-4">AI/ML Engineer & DevOps Architect</p>
          <p className="text-zinc-300 max-w-2xl mx-auto">
            Building production RAG systems with LangGraph, enterprise automation with MCP, 
            and reliable infrastructure with GitHub Actions + Azure. Ask about my current work!
          </p>
        </header>

        <div data-dev="content-area" className="grid lg:grid-cols-2 gap-8">
          {/* Left Panel - Avatar + Chat */}
          <div data-dev="avatar-column" className="bg-ink/90 backdrop-blur-sm border border-jade/30 rounded-lg shadow-2xl p-6">
            {/* Avatar Panel with voice & talking avatar */}
            <div className="mb-6">
              <AvatarPanel />
            </div>

            {/* Suggested Questions */}
            <div data-dev="suggestion-chips" className="mb-4">
              <div className="text-sm font-medium text-jade mb-2">Try asking:</div>
              <div className="flex flex-wrap gap-2">
                {suggestedQuestions.map((question, i) => (
                  <button
                    key={i}
                    data-dev={`suggestion-chip-${i}`}
                    onClick={() => send(question)}
                    disabled={busy}
                    className="px-3 py-1 text-sm bg-jade/10 hover:bg-jade/20 border border-jade/30 hover:border-jade/50 text-jade rounded-full transition-all duration-200 disabled:opacity-50"
                  >
                    {question}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Interface */}
            <div data-dev="chat-interface" className="space-y-3">
              <div className="flex gap-2">
                <input 
                  data-dev="chat-input"
                  value={q} 
                  onChange={(e) => setQ(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && send()}
                  placeholder="Ask about my RAG/LangGraph work, Jade @ ZRS, or DevOps..." 
                  className="flex-1 border border-jade/30 p-3 rounded-lg focus:ring-2 focus:ring-jade focus:border-jade bg-ink/50 text-white placeholder-zinc-400"
                />
                <button 
                  data-dev="send-button"
                  onClick={() => send()} 
                  disabled={busy} 
                  className="px-4 py-3 rounded-lg bg-jade text-ink hover:bg-jade-light disabled:bg-zinc-600 transition-colors"
                >
                  {busy ? '⏳' : 'Ask'}
                </button>
              </div>
              <div data-dev="chat-response" className="bg-ink/30 border border-jade/20 rounded-lg p-4 min-h-[200px] whitespace-pre-wrap">
                <div className="text-zinc-100">
                  {a || 'Ask me anything about my current AI/ML work, enterprise automation projects, or technical background!'}
                </div>
              </div>
            </div>
          </div>

          {/* Right Panel - Projects */}
          <div data-dev="projects-panel" className="space-y-6">
            {/* ZRS Management Project */}
            <div data-dev="jade-project" className="bg-ink/90 backdrop-blur-sm border border-jade/30 rounded-lg shadow-2xl p-6">
              <h3 className="text-xl font-bold text-jade mb-3">🏢 ZRS Management — LinkOps AIBOX (Jade)</h3>
              <p className="text-zinc-300 mb-4">
                Offline-first AI assistant for ZRS Management (Orlando, FL). Fine-tuned Phi‑3 (Colab) on ZRS policies
                and housing laws. RAG over tenant/vendor/workflow data. RPA for onboarding and work-order completion.
                MCP tools to send emails and reports to the right parties automatically.
              </p>
              <div className="bg-jade/10 border border-jade/30 rounded-lg p-4 mb-4">
                <div className="text-sm font-semibold text-jade mb-2">Architecture Flow:</div>
                <div className="text-sm text-zinc-300">
                  ZRS Data → Phi-3 Fine-tune → RAG + RPA → MCP Email/Reports
                </div>
              </div>
              <div className="flex flex-wrap gap-2 text-xs">
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">Phi-3</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">RAG</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">RPA</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">MCP</span>
              </div>
            </div>

            {/* LinkOps Afterlife */}
            <div data-dev="afterlife-project" className="bg-ink/90 backdrop-blur-sm border border-jade/30 rounded-lg shadow-2xl p-6">
              <h3 className="text-xl font-bold text-jade mb-3">💀 LinkOps Afterlife — Open Source Avatar</h3>
              <p className="text-zinc-300 mb-4">
                Avatar creation center for loved ones who have passed. Upload multiple photos for accuracy, add a 30‑second
                voice sample, and a personality description to guide responses. RAG ensures grounded, respectful answers.
              </p>
              <div className="bg-jade/10 border border-jade/30 rounded-lg p-4 mb-4">
                <div className="text-sm font-semibold text-jade mb-2">Processing Flow:</div>
                <div className="text-sm text-zinc-300">
                  Multi-Photos + Voice + Personality → Avatar → RAG Responses
                </div>
              </div>
              <div className="flex flex-wrap gap-2 text-xs">
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">Multi-Photo</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">Voice-Sample</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">Personality</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">RAG</span>
              </div>
            </div>

            {/* This Portfolio */}
            <div data-dev="portfolio-project" className="bg-ink/90 backdrop-blur-sm border border-jade/30 rounded-lg shadow-2xl p-6">
              <h3 className="text-xl font-bold text-jade mb-3">🤖 This Portfolio — Local LLM + RAG</h3>
              <p className="text-zinc-300 mb-4">
                Interactive demo powered by a small local model and ChromaDB for grounded answers about my DevSecOps, RAG,
                and LangGraph work.
              </p>
              <div className="bg-jade/10 border border-jade/30 rounded-lg p-4 mb-4">
                <div className="text-sm font-semibold text-jade mb-2">RAG Pipeline:</div>
                <div className="text-sm text-zinc-300">
                  Docs → Embeddings → ChromaDB → Context → LLM Response
                </div>
              </div>
              <div className="flex flex-wrap gap-2 text-xs">
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">Local-LLM</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">ChromaDB</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">DevSecOps</span>
                <span className="px-2 py-1 bg-jade/20 text-jade border border-jade/40 rounded">LangGraph</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Debug Toggle Button */}
      <button 
        data-dev="debug-toggle" 
        onClick={() => document.body.classList.toggle('debug')} 
        className="fixed bottom-3 right-3 px-3 py-1 text-xs border border-jade text-jade rounded hover:bg-jade hover:text-ink transition-colors"
      >
        DEV: Toggle outlines
      </button>
    </div>
  );
}