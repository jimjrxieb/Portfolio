import React, { useState } from "react";
import { makeAvatar, talkAvatar, API_BASE } from "../lib/api";

export default function AvatarPanel() {
  const [avatarId, setAvatarId] = useState<string>("");
  const [photoUrl, setPhotoUrl] = useState<string>("");
  const [uploading, setUploading] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [speechUrl, setSpeechUrl] = useState<string>("");
  
  // Default Sheyla avatar info
  const defaultAvatar = {
    name: "Sheyla",
    locale: "en-IN",
    description: "Professional Indian lady with warm, simple voice"
  };

  async function onUpload(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fileInput = form.querySelector<HTMLInputElement>('input[type="file"][name="photo"]');
    const voiceInput = form.querySelector<HTMLInputElement>('input[name="voice"]');
    if (!fileInput?.files?.[0]) return;

    const fd = new FormData();
    fd.append("photo", fileInput.files[0]);
    if (voiceInput?.value) fd.append("voice", voiceInput.value); // optional; server can default to Giancarlo

    setUploading(true);
    try {
      const res = await makeAvatar(fd);
      setAvatarId(res.avatar_id);
      setPhotoUrl(`${API_BASE}/api/assets/uploads/${res.avatar_id}.jpg`);
    } catch (err: any) {
      alert(err.message || "Avatar upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function onTalk(text: string) {
    setSpeaking(true);
    try {
      if (!avatarId) {
        // Fallback: Show that Sheyla would speak this text
        alert(`Sheyla (${defaultAvatar.locale}): "${text}"`);
        setSpeechUrl(""); // No audio in demo mode
      } else {
        const res = await talkAvatar({ avatar_id: avatarId, text });
        setSpeechUrl(res.url || "");
      }
    } catch (err: any) {
      // Demo fallback: Show text that would be spoken
      alert(`Sheyla (${defaultAvatar.locale}): "${text}"`);
      setSpeechUrl("");
    } finally {
      setSpeaking(false);
    }
  }

  return (
    <div className="space-y-3" data-dev="avatar-panel">
      <form onSubmit={onUpload} className="flex items-center gap-2">
        <input type="file" name="photo" accept="image/*" />
        <input type="text" name="voice" placeholder="(optional) voice id or 'giancarlo'" className="border rounded px-2 py-1" />
        <button className="border rounded px-3 py-1" disabled={uploading}>{uploading ? "Uploading…" : "Upload Avatar"}</button>
      </form>

      {/* Avatar Info Display */}
      <div className="bg-slate-50 rounded-lg p-3 mb-3">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">Avatar: {defaultAvatar.name}</span>
          <span className="text-xs text-slate-500">•</span>
          <span className="text-xs text-slate-500">Locale: {defaultAvatar.locale}</span>
        </div>
        <p className="text-xs text-slate-600 mt-1">{defaultAvatar.description}</p>
      </div>

      <div className="flex gap-3 items-start">
        <div className="w-28 h-28 rounded-xl overflow-hidden border bg-neutral-100 flex items-center justify-center">
          {photoUrl ? (
            <img src={photoUrl} alt="avatar" className="w-full h-full object-cover" />
          ) : (
            <span className="text-xs opacity-60">Default Sheyla</span>
          )}
        </div>
        <div className="space-y-2">
        <button
          className="border rounded px-3 py-1"
          onClick={() => onTalk("Hello! I'm Sheyla, and I'd love to tell you about Jimmie and his innovative AI projects. Jimmie creates solutions that make property management effortless through conversational AI.")}
          disabled={speaking}
        >
          ▶️ Play Introduction
        </button>
        <button
          className="border rounded px-3 py-1"
          onClick={() => onTalk("Tell me about LinkOps AI-BOX and how it helps property managers with their daily tasks.")}
          disabled={speaking}
        >
          🎬 Ask About Projects
        </button>
          {speechUrl && <audio controls src={speechUrl} className="block w-72" />}
        </div>
      </div>
    </div>
  );
}