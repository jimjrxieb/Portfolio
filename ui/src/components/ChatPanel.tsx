import React, { useEffect, useState } from 'react';
import ChatBox from './ChatBox';
import { API_BASE } from '../lib/api';

export default function ChatPanel() {
  const [health, setHealth] = useState<{
    llm_model?: string;
    llm_provider?: string;
    rag_namespace?: string;
    status?: string;
  }>({});

  useEffect(() => {
    fetch(`${API_BASE}/health`)
      .then(r => r.json())
      .then(data => setHealth(data))
      .catch(console.error);
  }, []);

  return (
    <div className="space-y-2">
      <div className="text-xs opacity-70 flex justify-between">
        <span>
          🤖 {health?.llm_provider || 'loading'}/{health?.llm_model || '…'} • 📚{' '}
          {health?.rag_namespace || 'portfolio'}
        </span>
        <span
          className={`${health?.status === 'healthy' ? 'text-green-600' : 'text-orange-600'}`}
        >
          {health?.status === 'healthy' ? '✅ RAG Active' : '⚠️ Degraded'}
        </span>
      </div>
      <ChatBox />
    </div>
  );
}
