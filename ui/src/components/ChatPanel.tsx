import React, { useEffect, useState } from 'react';
import ChatBoxFixed from './ChatBoxFixed';
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
      .then(data => {
        // Map backend health response to expected format
        setHealth({
          llm_model: data.model || 'gpt-4o-mini',
          llm_provider: 'openai',
          rag_namespace: 'portfolio',
          status: data.status,
        });
      })
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
      <ChatBoxFixed />
    </div>
  );
}
