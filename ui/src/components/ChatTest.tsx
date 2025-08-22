/**
 * Chat Test Component
 * Simple component to test backend communication
 */

import React, { useState } from 'react';

const ChatTest: React.FC = () => {
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const testHealthCheck = async () => {
    try {
      setLoading(true);
      setError('');

      const response = await fetch('http://localhost:8002/health');
      const data = await response.json();

      setResponse(JSON.stringify(data, null, 2));
    } catch (err) {
      setError('Failed to connect to backend: ' + err);
    } finally {
      setLoading(false);
    }
  };

  const testTTS = async () => {
    try {
      setLoading(true);
      setError('');

      const response = await fetch('http://localhost:8002/tts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: message || 'Hello, I am Gojo, your AI avatar!',
          voice: 'en-US-DavisNeural',
        }),
      });

      const data = await response.json();

      // Show only metadata, not the full audio data
      const summary = {
        duration_ms: data.duration_ms,
        voice: data.voice,
        visemes_count: data.visemes?.length || 0,
        first_visemes: data.visemes?.slice(0, 3) || [],
        audio_size: data.audio_base64?.length || 0,
      };

      setResponse(JSON.stringify(summary, null, 2));
    } catch (err) {
      setError('Failed to test TTS: ' + err);
    } finally {
      setLoading(false);
    }
  };

  const testAvatarStatus = async () => {
    try {
      setLoading(true);
      setError('');

      const response = await fetch('http://localhost:8002/status');
      const data = await response.json();

      setResponse(JSON.stringify(data, null, 2));
    } catch (err) {
      setError('Failed to get avatar status: ' + err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h2 className="text-2xl font-bold mb-4">🧪 Backend Communication Test</h2>

      <div className="grid md:grid-cols-2 gap-6">
        {/* Controls */}
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">
              Test Message (for TTS):
            </label>
            <input
              type="text"
              value={message}
              onChange={e => setMessage(e.target.value)}
              placeholder="Enter text to synthesize..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div className="space-y-2">
            <button
              onClick={testHealthCheck}
              disabled={loading}
              className="w-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
            >
              🏥 Test Health Check
            </button>

            <button
              onClick={testAvatarStatus}
              disabled={loading}
              className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              🤖 Test Avatar Status
            </button>

            <button
              onClick={testTTS}
              disabled={loading}
              className="w-full px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 disabled:opacity-50"
            >
              🎤 Test TTS & Visemes
            </button>
          </div>

          {loading && (
            <div className="text-center">
              <div className="animate-spin w-6 h-6 border-4 border-blue-500 border-t-transparent rounded-full mx-auto"></div>
              <p className="mt-2 text-sm text-gray-600">Testing...</p>
            </div>
          )}
        </div>

        {/* Response */}
        <div>
          <h3 className="text-lg font-semibold mb-2">Response:</h3>

          {error && (
            <div className="p-4 bg-red-100 border border-red-400 text-red-700 rounded-md mb-4">
              <strong>Error:</strong> {error}
            </div>
          )}

          {response && (
            <pre className="p-4 bg-gray-100 border rounded-md text-sm overflow-auto max-h-96">
              {response}
            </pre>
          )}
        </div>
      </div>

      <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-md">
        <h4 className="font-semibold text-blue-800 mb-2">
          🔗 Connection Status:
        </h4>
        <ul className="text-sm text-blue-700 space-y-1">
          <li>• Frontend (UI): http://localhost:5173 ✅</li>
          <li>
            • Backend (Avatar): http://localhost:8002 {loading ? '🔄' : '✅'}
          </li>
          <li>• Mock TTS Service: {loading ? '🔄' : '✅'}</li>
        </ul>
      </div>
    </div>
  );
};

export default ChatTest;
