import { useEffect, useRef, useState } from "react";
import { chat } from "../lib/api";

export default function ChatBox() {
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [history, setHistory] = useState([]);
  const abortRef = useRef(null);

  async function onSend(e) {
    e?.preventDefault();
    if (!input.trim() || busy) return;
    setBusy(true); setError("");

    // optimistic UI
    const q = input.trim();
    setHistory(h => [...h, { role: "user", text: q }]);
    setInput("");

    abortRef.current?.abort?.();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const res = await chat({ message: q, namespace: "portfolio", k: 5 }, controller.signal);
      setHistory(h => [...h, { role: "assistant", text: res.answer, citations: res.citations, model: res.model }]);
    } catch (err) {
      console.error(err);
      setError(err.message || "Chat failed");
      setHistory(h => [...h, { role: "assistant", text: "Sorry—something went wrong reaching my brain.", citations: [] }]);
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => () => abortRef.current?.abort?.(), []);

  return (
    <div className="w-full h-full flex flex-col gap-3" data-dev="chat-box">
      <div className="flex-1 overflow-auto rounded-xl border p-3">
        {history.length === 0 && (
          <div className="opacity-70">Try asking: "Tell me about the Jade project"</div>
        )}
        {history.map((m, i) => (
          <div key={i} className={`mb-3 ${m.role === "user" ? "text-right" : "text-left"}`}>
            <div className={`inline-block rounded-2xl px-3 py-2 ${m.role === "user" ? "bg-blue-500/10" : "bg-neutral-500/10"}`}>
              <div className="whitespace-pre-wrap">{m.text}</div>
              {m.citations?.length > 0 && (
                <ul className="mt-2 text-xs opacity-75 list-disc pl-4">
                  {m.citations.slice(0, 3).map((c, j) => (
                    <li key={j}>
                      {c.metadata?.source || c.metadata?.project || "context"} • score {c.score.toFixed(2)}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        ))}
      </div>

      {error && <div className="text-red-500 text-sm" data-dev="chat-error">{error}</div>}

      <form onSubmit={onSend} className="flex gap-2">
        <input
          className="flex-1 rounded-xl border px-3 py-2"
          placeholder="Ask about my AI/ML or DevSecOps work…"
          value={input}
          onChange={e => setInput(e.target.value)}
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded-xl px-4 py-2 border hover:bg-black/5 disabled:opacity-50"
        >
          {busy ? "Thinking…" : "Ask"}
        </button>
      </form>
    </div>
  );
}