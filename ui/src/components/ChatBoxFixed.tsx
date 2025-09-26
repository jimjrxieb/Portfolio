/**
 * Fixed ChatBox Component
 * Simple, working chat interface for Gojo
 */

import React, { useState } from 'react';
import { API_BASE } from '../lib/api';

interface ChatMessage {
  id: string;
  text: string;
  sender: 'user' | 'jade';
  timestamp: Date;
}

const ChatBoxFixed: React.FC = () => {
  const [message, setMessage] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const quickPrompts = [
    "Tell me about Jimmie's DevSecOps experience",
    'What is LinkOps AI-BOX?',
    'What technologies does Jimmie use?',
    'How was the CI/CD pipeline built?',
    'What security tools were implemented?',
  ];

  const sendMessage = async (text: string) => {
    if (!text.trim()) return;

    const userMessage: ChatMessage = {
      id: Date.now() + '-user',
      text: text.trim(),
      sender: 'user',
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setMessage('');
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: text.trim(),
          audience_type: 'general',
        }),
      });

      if (!response.ok) {
        const errorData = await response
          .json()
          .catch(() => ({ detail: 'Unknown error' }));
        throw new Error(errorData.detail || `HTTP ${response.status}`);
      }

      const data = await response.json();

      const jadeMessage: ChatMessage = {
        id: Date.now() + '-jade',
        text: data.response || "I'm having trouble responding right now.",
        sender: 'jade',
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, jadeMessage]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');

      // Add error message to chat
      const errorMessage: ChatMessage = {
        id: Date.now() + '-error',
        text: `Sorry—something went wrong reaching my brain.\n${err instanceof Error ? err.message : 'Unknown error'}`,
        sender: 'jade',
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    sendMessage(message);
  };

  const handleQuickPrompt = (prompt: string) => {
    sendMessage(prompt);
  };

  return (
    <div className="space-y-4">
      {/* Chat Messages */}
      <div className="space-y-3 max-h-96 overflow-y-auto">
        {messages.length === 0 && (
          <div className="text-center text-gray-500 py-8">
            <p>👋 Hi! I'm Jade, Jimmie's AI assistant.</p>
            <p className="text-sm mt-1">
              Ask me about his DevSecOps or AI/ML work...
            </p>
          </div>
        )}

        {messages.map(msg => (
          <div
            key={msg.id}
            className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                msg.sender === 'user'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-800'
              }`}
            >
              <p className="text-sm whitespace-pre-wrap">{msg.text}</p>
              <p className="text-xs opacity-70 mt-1">
                {msg.timestamp.toLocaleTimeString()}
              </p>
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 text-gray-800 px-4 py-2 rounded-lg">
              <div className="flex items-center space-x-2">
                <div className="animate-spin w-4 h-4 border-2 border-blue-600 border-t-transparent rounded-full"></div>
                <span className="text-sm">Jade is thinking...</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Error Display */}
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          <p className="text-sm">
            <strong>Error:</strong> {error}
          </p>
        </div>
      )}

      {/* Quick Prompts */}
      <div className="space-y-2">
        <p className="text-xs text-gray-600">Quick asks:</p>
        <div className="flex flex-wrap gap-2">
          {quickPrompts.slice(0, 3).map((prompt, index) => (
            <button
              key={index}
              onClick={() => handleQuickPrompt(prompt)}
              disabled={loading}
              className="text-xs bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-1 rounded-full transition-colors disabled:opacity-50"
            >
              {prompt.length > 25 ? prompt.substring(0, 25) + '...' : prompt}
            </button>
          ))}
        </div>
      </div>

      {/* Input Form */}
      <form onSubmit={handleSubmit} className="space-y-2">
        <div className="flex space-x-2">
          <input
            type="text"
            value={message}
            onChange={e => setMessage(e.target.value)}
            placeholder="Ask about my AI/ML or DevSecOps work..."
            disabled={loading}
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
          />
          <button
            type="submit"
            disabled={loading || !message.trim()}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Ask
          </button>
        </div>
      </form>

      {/* Connection Status */}
      <div className="text-xs text-gray-500 flex items-center justify-between">
        <span>Backend: {API_BASE}</span>
        <span className={loading ? 'text-yellow-600' : 'text-green-600'}>
          {loading ? '🔄 Connecting...' : '✅ Ready'}
        </span>
      </div>
    </div>
  );
};

export default ChatBoxFixed;
