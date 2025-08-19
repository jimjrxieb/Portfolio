import React, { useState } from 'react';
import { makeAvatar, talkAvatar, API_BASE } from '../lib/api';

export default function AvatarPanel() {
  const [avatarId, setAvatarId] = useState<string>('');
  const [photoUrl, setPhotoUrl] = useState<string>('');
  const [uploading, setUploading] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [speechUrl, setSpeechUrl] = useState<string>('');

  // Default Gojo avatar info
  const defaultAvatar = {
    name: 'Gojo',
    locale: 'en-US',
    description:
      'Professional male with white hair and crystal blue eyes, confident voice',
  };

  async function onUpload(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fileInput = form.querySelector<HTMLInputElement>(
      'input[type="file"][name="photo"]'
    );
    const voiceInput = form.querySelector<HTMLInputElement>(
      'input[name="voice"]'
    );
    if (!fileInput?.files?.[0]) return;

    const fd = new FormData();
    fd.append('photo', fileInput.files[0]);
    if (voiceInput?.value) fd.append('voice', voiceInput.value); // optional; server can default to Gojo voice

    setUploading(true);
    try {
      const res = await makeAvatar(fd);
      setAvatarId(res.avatar_id);
      setPhotoUrl(`${API_BASE}/api/assets/uploads/${res.avatar_id}.jpg`);
    } catch (err: any) {
      alert(err.message || 'Avatar upload failed');
    } finally {
      setUploading(false);
    }
  }

  async function onTalk(text: string) {
    setSpeaking(true);
    try {
      if (!avatarId) {
        // Fallback: Show that Gojo would speak this text
        alert(`Gojo (${defaultAvatar.locale}): "${text}"`);
        setSpeechUrl('/intro.mp3'); // Default intro audio in demo mode
      } else {
        const res = await talkAvatar({ avatar_id: avatarId, text });
        setSpeechUrl(res.url || '/intro.mp3'); // Fallback to default intro
      }
    } catch (err: any) {
      // Demo fallback: Show text that would be spoken
      alert(`Gojo (${defaultAvatar.locale}): "${text}"`);
      setSpeechUrl('/intro.mp3'); // Fallback to default audio
    } finally {
      setSpeaking(false);
    }
  }

  return (
    <div className="space-y-3" data-dev="avatar-panel">
      <form onSubmit={onUpload} className="flex items-center gap-2">
        <input type="file" name="photo" accept="image/*" />
        <input
          type="text"
          name="voice"
          placeholder="(optional) voice id or 'gojo'"
          className="border rounded px-2 py-1"
        />
        <button className="border rounded px-3 py-1" disabled={uploading}>
          {uploading ? 'Uploading…' : 'Upload Avatar'}
        </button>
      </form>

      {/* Avatar Info Display */}
      <div className="bg-slate-50 rounded-lg p-3 mb-3">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">
            Avatar: {defaultAvatar.name}
          </span>
          <span className="text-xs text-slate-500">•</span>
          <span className="text-xs text-slate-500">
            Locale: {defaultAvatar.locale}
          </span>
        </div>
        <p className="text-xs text-slate-600 mt-1">
          {defaultAvatar.description}
        </p>
      </div>

      <div className="flex gap-3 items-start">
        <div className="w-28 h-28 rounded-xl overflow-hidden border bg-neutral-100 flex items-center justify-center">
          {photoUrl ? (
            <img
              src={photoUrl}
              alt="avatar"
              className="w-full h-full object-cover"
            />
          ) : (
            <img
              src="/avatar.jpg"
              alt="Default Gojo Avatar"
              className="w-full h-full object-cover"
            />
          )}
        </div>
        <div className="space-y-2">
          <button
            className="border rounded px-3 py-1"
            onClick={() =>
              onTalk(
                "Hello! I'm Gojo, and I'm excited to tell you about Jimmie Coleman and his current venture. Jimmie is raising funding for LinkOps AI-BOX - a revolutionary plug-and-play AI system designed for companies hesitant about cloud-based AI due to security concerns."
              )
            }
            disabled={speaking}
          >
            ▶️ Play Introduction
          </button>
          <button
            className="border rounded px-3 py-1"
            onClick={() =>
              onTalk(
                'Tell me about LinkOps AI-BOX and how the dual-speed CI/CD workflow enables instant knowledge updates for enterprise AI deployments.'
              )
            }
            disabled={speaking}
          >
            🎬 Ask About Projects
          </button>
          {speechUrl && (
            <audio controls src={speechUrl} className="block w-72" />
          )}
        </div>
      </div>
    </div>
  );
}
