// data-dev:ui-avatar-panel
import { useState, useRef } from "react"

const API_BASE = "/api" // same-origin via your Ingress

// data-dev:ui-voice-presets
const VOICE_PRESETS = [
  { id: "default", label: "Default Voice" },
  { id: "giancarlo", label: "Giancarlo Style" },
];

export default function AvatarPanel() {
  const [loading, setLoading] = useState(false)
  const [videoUrl, setVideoUrl] = useState<string | null>(null)
  const [talkId, setTalkId] = useState<string | null>(null)
  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [selectedVoice, setSelectedVoice] = useState('default')
  const fileRef = useRef<HTMLInputElement | null>(null)

  async function playIntro() {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE}/voice/tts`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "Hi, I'm Jimmie. Welcome to my portfolio!" }),
      })
      if (!res.ok) throw new Error("TTS failed")
      const data = await res.json()
      new Audio(data.url).play()
    } finally {
      setLoading(false)
    }
  }

  async function uploadImage(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setLoading(true)
    try {
      const form = new FormData()
      form.append("file", file)
      const res = await fetch(`${API_BASE}/upload/image`, { method: "POST", body: form })
      if (!res.ok) throw new Error("Upload failed")
      const data = await res.json()
      setImageUrl(data.url)
    } finally {
      setLoading(false)
    }
  }

  async function makeAvatarTalk() {
    if (!imageUrl) {
      fileRef.current?.focus()
      alert("Upload an image first.")
      return
    }
    setLoading(true)
    setVideoUrl(null)
    try {
      const res = await fetch(`${API_BASE}/avatar/talk`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: "This is my Afterlife demo. Ask me about Jade or my DevSecOps work.",
          image_url: imageUrl,
        }),
      })
      if (!res.ok) throw new Error("Create talk failed")
      const data = await res.json()
      setTalkId(data.talk_id)

      const poll = async () => {
        const r = await fetch(`${API_BASE}/avatar/talk/${data.talk_id}`)
        const s = await r.json()
        if (s.result_url) {
          setVideoUrl(s.result_url)
          setLoading(false)
        } else {
          setTimeout(poll, 1500)
        }
      }
      poll()
    } catch {
      setLoading(false)
    }
  }

  return (
    <div data-dev="avatar-section" className="text-center">
      <div className="relative inline-block mb-4">
        {imageUrl ? (
          <img 
            data-dev="image-preview" 
            src={imageUrl} 
            alt="avatar" 
            className="w-32 h-32 rounded-2xl object-cover shadow-2xl border-4 border-jade/60" 
          />
        ) : (
          <div className="w-32 h-32 rounded-2xl bg-jade/10 border-4 border-jade/30 flex items-center justify-center text-jade text-4xl">
            👨‍💻
          </div>
        )}
      </div>

      <div className="mb-4 space-y-3">
        <label className="block">
          <input
            data-dev="image-input"
            ref={fileRef}
            type="file"
            accept="image/*"
            onChange={uploadImage}
            className="hidden"
          />
          <span className="cursor-pointer px-4 py-2 bg-jade/20 hover:bg-jade/30 border border-jade/50 text-jade rounded-xl transition-colors text-sm font-medium">
            {imageUrl ? "Change Avatar" : "Upload Avatar"}
          </span>
        </label>

        {/* Voice Selection */}
        <div data-dev="voice-selection" className="text-center">
          <label className="block text-sm text-jade mb-1">Voice Style:</label>
          <select 
            data-dev="voice-select" 
            value={selectedVoice}
            onChange={(e) => setSelectedVoice(e.target.value)}
            className="rounded bg-black border border-jade/50 px-3 py-1 text-white text-sm"
          >
            {VOICE_PRESETS.map(v => (
              <option key={v.id} value={v.id}>{v.label}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="space-y-3">
        <button
          data-dev="intro-button"
          className="w-full px-4 py-2 bg-jade hover:bg-jade-light text-black rounded-lg font-medium transition-colors disabled:opacity-50"
          onClick={playIntro}
          disabled={loading}
        >
          {loading ? "Loading..." : "▶️ Play Introduction"}
        </button>

        <button
          data-dev="talk-button"
          className="w-full px-4 py-2 border border-jade text-jade rounded-lg hover:bg-jade hover:text-black transition-colors disabled:opacity-50"
          onClick={makeAvatarTalk}
          disabled={loading || !imageUrl}
        >
          {loading ? "Working..." : "🎬 Make Avatar Talk"}
        </button>
      </div>

      {talkId && !videoUrl && (
        <p data-dev="talk-status" className="text-sm text-zinc-400 mt-3">
          Generating avatar video… (id: {talkId})
        </p>
      )}

      {videoUrl && (
        <div className="mt-4">
          <video data-dev="talk-video" controls autoPlay className="w-full max-w-sm rounded-lg shadow-2xl border border-jade/30">
            <source src={videoUrl} type="video/mp4" />
          </video>
        </div>
      )}
    </div>
  )
}