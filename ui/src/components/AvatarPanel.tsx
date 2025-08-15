import React, { useState } from "react";
import { makeAvatar, talkAvatar } from "../lib/api";

export default function AvatarPanel() {
  const [avatarId, setAvatarId] = useState<string>("");
  const [uploading, setUploading] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [speechUrl, setSpeechUrl] = useState<string>("");

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
    } catch (err: any) {
      alert(err.message || "Avatar upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function onTalk(text: string) {
    if (!avatarId) return alert("Create the avatar first.");
    setSpeaking(true);
    try {
      const res = await talkAvatar({ avatar_id: avatarId, text });
      setSpeechUrl(res.url);
    } catch (err: any) {
      alert(err.message || "Talk failed");
    } finally {
      setSpeaking(false);
    }
  }

  return (
    <div className="space-y-3" data-dev="avatar-panel">
      <form onSubmit={onUpload} className="flex items-center gap-2">
        <input type="file" name="photo" accept="image/*" />
        <input type="text" name="voice" placeholder="(optional) voice id" className="border rounded px-2 py-1" />
        <button className="border rounded px-3 py-1" disabled={uploading}>{uploading ? "Uploading…" : "Upload Avatar"}</button>
      </form>

      <div className="flex gap-2">
        <button
          className="border rounded px-3 py-1"
          onClick={() => onTalk("Hi, I'm Jimmie Coleman. Ask me about my AI/ML and DevSecOps work.")}
          disabled={!avatarId || speaking}
        >
          ▶️ Play Introduction
        </button>
        <button
          className="border rounded px-3 py-1"
          onClick={() => onTalk("Tell me about your DevOps pipeline.")}
          disabled={!avatarId || speaking}
        >
          🎬 Make Avatar Talk
        </button>
      </div>

      {speechUrl && (
        <audio controls src={speechUrl} className="w-full">
          Your browser does not support the audio element.
        </audio>
      )}
    </div>
  );
}