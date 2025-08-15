import { useState } from 'react';

async function askMe(message: string) {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message })
  });
  if (!res.ok) throw new Error(await res.text().catch(() => `status ${res.status}`));
  return res.json() as Promise<{ answer: string; context: string[] }>;
}

export default function InterviewPanel() {
  const [avatarUrl, setAvatarUrl] = useState('/uploads/images/avatar.jpg');
  const [introUrl, setIntroUrl] = useState('/uploads/audio/intro.webm');
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

  const send = async () => {
    if (!q.trim()) return;
    setBusy(true);
    setA('');
    try {
      const r = await askMe(q);
      setA(r.answer);
    } catch (e: any) {
      setA('Sorry, chat failed.');
      console.error(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <div className="md:col-span-1 flex flex-col items-center gap-3">
        <img 
          src={avatarUrl} 
          className="w-40 h-40 rounded-full object-cover border"
          onError={() => setAvatarUrl('/placeholder-avatar.png')}
        />
        <button 
          onClick={playIntro} 
          className="px-3 py-2 rounded-xl shadow bg-blue-500 text-white hover:bg-blue-600"
        >
          ▶️ Play Introduction
        </button>
        <label className="text-sm text-center">
          Upload avatar
          <input 
            type="file" 
            accept="image/*"
            className="block mt-1 text-xs"
            onChange={async (e) => {
              const f = e.target.files?.[0];
              if (!f) return;
              const fd = new FormData();
              fd.append('file', f);
              try {
                const r = await fetch('/api/upload/image', { method: 'POST', body: fd });
                const d = await r.json();
                setAvatarUrl(d.url);
              } catch (err) {
                alert('Upload failed');
              }
            }}
          />
        </label>
        <label className="text-sm text-center">
          Record/Upload intro
          <input 
            type="file" 
            accept="audio/*"
            className="block mt-1 text-xs"
            onChange={async (e) => {
              const f = e.target.files?.[0];
              if (!f) return;
              const fd = new FormData();
              fd.append('file', f);
              try {
                const r = await fetch('/api/upload/audio', { method: 'POST', body: fd });
                const d = await r.json();
                setIntroUrl(d.url);
              } catch (err) {
                alert('Upload failed');
              }
            }}
          />
        </label>
      </div>
      <div className="md:col-span-2">
        <div className="mb-2 font-semibold">Ask Me</div>
        <div className="flex gap-2">
          <input 
            value={q} 
            onChange={(e) => setQ(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && send()}
            placeholder="Ask about my DevOps/MLOps or Afterlife…" 
            className="flex-1 border p-2 rounded"
          />
          <button 
            onClick={send} 
            disabled={busy} 
            className="px-3 py-2 rounded bg-black text-white disabled:bg-gray-400"
          >
            {busy ? '…' : 'Ask'}
          </button>
        </div>
        <div className="mt-3 whitespace-pre-wrap min-h-[100px] p-3 bg-gray-50 rounded">
          {a || 'Ask me anything about my experience, projects, or background!'}
        </div>
      </div>
    </div>
  );
}