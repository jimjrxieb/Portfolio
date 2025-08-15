import { useState } from "react"
const API_BASE = "/api"

export default function ChatPanel() {
  const [q, setQ] = useState("")
  const [a, setA] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function ask() {
    setLoading(true)
    setA(null)
    try {
      const r = await fetch(`${API_BASE}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: q })
      })
      const data = await r.json()
      if (!r.ok) throw new Error(data.detail || "chat failed")
      setA(data.answer)
    } catch (e: any) {
      setA(`Error: ${e.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div data-dev="chat-panel" className="flex flex-col gap-3">
      <input value={q} onChange={e => setQ(e.target.value)} placeholder="Ask Jade…" 
             className="w-full rounded bg-black border border-jade/50 px-3 py-2 text-white" />
      <button onClick={ask} disabled={loading} className="self-start px-4 py-2 bg-jade text-black rounded hover:bg-jade-light">
        {loading ? "Thinking…" : "Ask"}
      </button>
      {a && <div data-dev="chat-answer" className="whitespace-pre-wrap text-zinc-100">{a}</div>}
    </div>
  )
}