import { useState } from 'react';
import { MessageCircle, Upload, Play, ChevronDown, ChevronUp, Sparkles, Brain, Building, Cpu } from 'lucide-react';

async function askMe(message: string) {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message })
  });
  if (!res.ok) throw new Error(await res.text().catch(() => `status ${res.status}`));
  return res.json() as Promise<{ answer: string; context: string[] }>;
}

const suggestedQuestions = [
  "What AI/ML work are you focused on?",
  "Tell me about the Jade project",
  "What's your current DevOps pipeline?", 
  "How does your RAG system work?"
];

export default function ModernHome() {
  const [avatarUrl, setAvatarUrl] = useState('/uploads/images/avatar.jpg');
  const [introUrl, setIntroUrl] = useState('/uploads/audio/intro.webm');
  const [q, setQ] = useState('');
  const [a, setA] = useState('');
  const [busy, setBusy] = useState(false);
  const [expandedProject, setExpandedProject] = useState<string | null>(null);

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
      setA('Sorry, chat failed. Please try again.');
      console.error(e);
    } finally {
      setBusy(false);
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

  return (
    <div data-dev="main-container" className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black font-['Inter',sans-serif]">
      {/* Header */}
      <div data-dev="hero-section" className="pt-8 pb-4 text-center relative">
        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-jade/10 to-transparent"></div>
        <div className="relative z-10">
          <h1 className="text-4xl font-bold text-text-primary mb-2">Jimmie Coleman</h1>
          <p className="text-xl text-jade mb-3">AI/ML Engineer & DevOps Architect</p>
          <p className="text-text-secondary max-w-2xl mx-auto px-4">
            Building production RAG systems with LangGraph, enterprise automation, and reliable infrastructure. 
            <span className="inline-flex items-center ml-1">
              <Sparkles className="w-4 h-4 text-jade" />
            </span>
          </p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-2 gap-8">
          
          {/* Left Panel - Avatar + Chat */}
          <div data-dev="chat-panel" className="bg-black/90 backdrop-blur-sm rounded-2xl shadow-2xl border border-jade/30 p-8">
            {/* Avatar Section */}
            <div data-dev="avatar-section" className="text-center mb-8">
              <div className="relative inline-block">
                <img 
                  src={avatarUrl} 
                  className="w-32 h-32 rounded-2xl object-cover shadow-2xl border-4 border-jade/60"
                  onError={() => setAvatarUrl('/placeholder-avatar.png')}
                  alt="Jimmie Coleman"
                />
                <div className="absolute -bottom-2 -right-2">
                  <button 
                    data-dev="play-intro-btn"
                    onClick={playIntro} 
                    className="bg-jade hover:bg-jade-light text-black p-3 rounded-full shadow-lg transition-all duration-200 hover:scale-105"
                  >
                    <Play className="w-4 h-4 fill-current" />
                  </button>
                </div>
              </div>
              
              {/* Upload Controls */}
              <div data-dev="upload-controls" className="flex justify-center gap-4 mt-6">
                <label data-dev="avatar-upload" className="flex items-center gap-2 px-4 py-2 bg-jade/20 hover:bg-jade/30 border border-jade/50 text-jade rounded-xl cursor-pointer transition-colors text-sm font-medium">
                  <Upload className="w-4 h-4" />
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
                <label data-dev="intro-upload" className="flex items-center gap-2 px-4 py-2 bg-jade/20 hover:bg-jade/30 border border-jade/50 text-jade rounded-xl cursor-pointer transition-colors text-sm font-medium">
                  <Upload className="w-4 h-4" />
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
            </div>

            {/* Suggested Questions */}
            <div data-dev="suggestion-chips" className="mb-6">
              <div className="text-sm font-medium text-jade mb-3 flex items-center gap-2">
                <MessageCircle className="w-4 h-4" />
                Try asking:
              </div>
              <div className="flex flex-wrap gap-2">
                {suggestedQuestions.map((question, i) => (
                  <button
                    key={i}
                    data-dev={`suggestion-chip-${i}`}
                    onClick={() => send(question)}
                    disabled={busy}
                    className="px-3 py-2 text-sm bg-jade/10 hover:bg-jade/20 border border-jade/30 hover:border-jade/50 text-jade rounded-full transition-all duration-200 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {question}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Interface */}
            <div data-dev="chat-interface" className="space-y-4">
              <div className="flex gap-3">
                <input 
                  data-dev="chat-input"
                  value={q} 
                  onChange={(e) => setQ(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && send()}
                  placeholder="Ask about my RAG/LangGraph work, Jade @ ZRS, or DevOps..." 
                  className="flex-1 px-4 py-3 border border-jade/30 rounded-xl focus:ring-2 focus:ring-jade focus:border-jade bg-black/50 backdrop-blur-sm text-text-primary placeholder-text-secondary"
                  disabled={busy}
                />
                <button 
                  data-dev="send-button"
                  onClick={() => send()} 
                  disabled={busy || !q.trim()} 
                  className="px-6 py-3 bg-jade hover:bg-jade-light text-black rounded-xl font-medium transition-all duration-200 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                >
                  {busy ? (
                    <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  ) : (
                    'Ask'
                  )}
                </button>
              </div>
              
              {/* Chat Response */}
              <div data-dev="chat-response" className="bg-black/30 backdrop-blur-sm rounded-xl p-6 min-h-[200px] border border-jade/20">
                {a ? (
                  <div className="whitespace-pre-wrap text-text-primary leading-relaxed">
                    {a}
                  </div>
                ) : (
                  <div className="text-text-secondary italic text-center py-12">
                    Ask me anything about my current AI/ML work, enterprise automation projects, or technical background!
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Right Panel - Projects */}
          <div data-dev="projects-panel" className="space-y-6">
            
            {/* Jade @ ZRS */}
            <div data-dev="jade-project" className="bg-black/90 backdrop-blur-sm rounded-2xl shadow-2xl border border-jade/30 overflow-hidden">
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-jade rounded-lg">
                      <Building className="w-6 h-6 text-black" />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-text-primary">ZRS Management — LinkOps AIBOX (Jade)</h3>
                      <p className="text-jade text-sm">Offline DevSecOps AI Assistant</p>
                    </div>
                  </div>
                  <button
                    data-dev="jade-expand-btn"
                    onClick={() => setExpandedProject(expandedProject === 'jade' ? null : 'jade')}
                    className="p-1 hover:bg-jade/20 rounded-lg transition-colors text-jade"
                  >
                    {expandedProject === 'jade' ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                  </button>
                </div>
                
                <p className="text-text-secondary mt-4 leading-relaxed">
                  Offline-first AI assistant for ZRS Management (Orlando, FL). Fine-tuned Phi‑3 (Colab) on ZRS policies
                  and housing laws. RAG over tenant/vendor/workflow data. RPA for onboarding and work-order completion.
                  MCP tools to send emails and reports to the right parties automatically.
                </p>
                
                {expandedProject === 'jade' && (
                  <div data-dev="jade-expanded" className="mt-4 space-y-4">
                    <div className="bg-jade/10 rounded-xl p-4 border border-jade/30">
                      <div className="text-sm font-semibold text-jade mb-2">Architecture Flow:</div>
                      <div className="text-sm text-text-secondary font-mono">
                        Documents → OCR + NLP → ChromaDB → LangGraph → BI Dashboard
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {['Phi-3', 'RAG', 'RPA', 'MCP', 'Colab'].map((tech) => (
                        <span key={tech} data-dev={`jade-tech-${tech.toLowerCase()}`} className="px-3 py-1 text-xs font-medium bg-jade/20 text-jade rounded-full border border-jade/40">
                          {tech}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Afterlife OSS */}
            <div className="bg-white/70 backdrop-blur-sm rounded-2xl shadow-xl border border-white/50 overflow-hidden">
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-gradient-to-r from-purple-500 to-pink-600 rounded-lg">
                      <Brain className="w-6 h-6 text-white" />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">LinkOps Afterlife — Open Source Avatar</h3>
                      <p className="text-slate-500 text-sm">Multi-Photo Avatar Creation Center</p>
                    </div>
                  </div>
                  <button
                    onClick={() => setExpandedProject(expandedProject === 'afterlife' ? null : 'afterlife')}
                    className="p-1 hover:bg-slate-100 rounded-lg transition-colors"
                  >
                    {expandedProject === 'afterlife' ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                  </button>
                </div>
                
                <p className="text-slate-600 mt-4 leading-relaxed">
                  Avatar creation center for loved ones who have passed. Upload multiple photos for accuracy, add a 30‑second
                  voice sample, and a personality description to guide responses. RAG ensures grounded, respectful answers.
                </p>
                
                {expandedProject === 'afterlife' && (
                  <div className="mt-4 space-y-4">
                    <div className="bg-gradient-to-r from-purple-50 to-pink-50 rounded-xl p-4 border border-purple-200/50">
                      <div className="text-sm font-semibold text-purple-800 mb-2">Processing Flow:</div>
                      <div className="text-sm text-purple-700 font-mono">
                        User Input → RAG Context → LLM → Avatar Response + Speech
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {['Multi-Photo', 'Voice-Sample', 'Personality', 'RAG', 'D-ID'].map((tech) => (
                        <span key={tech} className="px-3 py-1 text-xs font-medium bg-gradient-to-r from-purple-100 to-pink-100 text-purple-800 rounded-full border border-purple-200/50">
                          {tech}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* This Portfolio */}
            <div className="bg-white/70 backdrop-blur-sm rounded-2xl shadow-xl border border-white/50 overflow-hidden">
              <div className="p-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-lg">
                      <Cpu className="w-6 h-6 text-white" />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">This Portfolio — Local LLM + RAG</h3>
                      <p className="text-slate-500 text-sm">Interactive Demo</p>
                    </div>
                  </div>
                  <button
                    onClick={() => setExpandedProject(expandedProject === 'portfolio' ? null : 'portfolio')}
                    className="p-1 hover:bg-slate-100 rounded-lg transition-colors"
                  >
                    {expandedProject === 'portfolio' ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                  </button>
                </div>
                
                <p className="text-slate-600 mt-4 leading-relaxed">
                  Interactive demo powered by a small local model and ChromaDB for grounded answers about my DevSecOps, RAG,
                  and LangGraph work.
                </p>
                
                {expandedProject === 'portfolio' && (
                  <div className="mt-4 space-y-4">
                    <div className="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl p-4 border border-blue-200/50">
                      <div className="text-sm font-semibold text-blue-800 mb-2">RAG Pipeline:</div>
                      <div className="text-sm text-blue-700 font-mono">
                        Docs → Embeddings → ChromaDB → Context → LLM Response
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {['Local-LLM', 'ChromaDB', 'DevSecOps', 'LangGraph', 'React'].map((tech) => (
                        <span key={tech} className="px-3 py-1 text-xs font-medium bg-gradient-to-r from-blue-100 to-indigo-100 text-blue-800 rounded-full border border-blue-200/50">
                          {tech}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}