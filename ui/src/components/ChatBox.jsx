import { useState } from 'react';

export default function ChatBox({ placeholder }) {
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!message.trim() || isLoading) return;

    setIsLoading(true);
    setResponse('');

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: message,
          use_rag: true
        })
      });

      if (!res.ok) throw new Error('Network response was not ok');

      const reader = res.body.getReader();
      let fullResponse = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = new TextDecoder().decode(value);
        const lines = chunk.split('\n');
        
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            if (data === '[DONE]') return;
            fullResponse += data;
            setResponse(fullResponse);
          }
        }
      }
    } catch (error) {
      setResponse(`Error: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="panel">
      <h3>Ask James</h3>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          className="chat-input"
          placeholder={placeholder}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          disabled={isLoading}
        />
        <button 
          type="submit" 
          className="send-button" 
          disabled={!message.trim() || isLoading}
        >
          {isLoading ? '⏳ Thinking...' : '💬 Ask'}
        </button>
      </form>
      
      {(response || isLoading) && (
        <div className="chat-response">
          {isLoading && !response && <div className="loading">Thinking...</div>}
          {response && <div>{response}</div>}
        </div>
      )}
    </div>
  );
}