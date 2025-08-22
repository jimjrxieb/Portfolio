import React, { useState, useRef } from 'react';
import { API_BASE } from '../lib/api';
import GojoAvatar3D, { GojoAvatar3DRef } from './GojoAvatar3D';

export default function AvatarPanel() {
  const [speaking, setSpeaking] = useState(false);
  const [speechUrl, setSpeechUrl] = useState<string>('');
  const avatarRef = useRef<GojoAvatar3DRef>(null);

  async function onTalk(text: string) {
    setSpeaking(true);
    try {
      // Generate TTS with visemes using our backend
      const response = await fetch(`${API_BASE}/tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text,
          voice: 'en-US-DavisNeural',
          include_visemes: true,
        }),
      });

      if (!response.ok) {
        throw new Error(`TTS failed: ${response.status}`);
      }

      const data = await response.json();

      // Convert base64 audio to blob URL for the audio controls
      const audioBytes = atob(data.audio_base64);
      const audioArray = new Uint8Array(audioBytes.length);
      for (let i = 0; i < audioBytes.length; i++) {
        audioArray[i] = audioBytes.charCodeAt(i);
      }
      // Detect audio type from the base64 header or use MP3 as default
      const audioType = data.audio_base64.startsWith('UklGR') ? 'audio/wav' : 'audio/mp3';
      const audioBlob = new Blob([audioArray], { type: audioType });
      const audioUrl = URL.createObjectURL(audioBlob);
      setSpeechUrl(audioUrl);

      // Send TTS data to 3D avatar for lip-sync
      if (avatarRef.current) {
        await avatarRef.current.speak(data);
      }
    } catch (err: any) {
      console.error('TTS error:', err);
      alert(`Speech generation failed: ${err.message}`);
    } finally {
      setSpeaking(false);
    }
  }

  return (
    <div className="space-y-4" data-dev="avatar-panel">
      {/* Avatar Info Display */}
      <div className="bg-snow/20 rounded-lg p-3 border border-white/10">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-gojo-primary">
            Avatar: Gojo
          </span>
          <span className="text-xs text-gojo-secondary">•</span>
          <span className="text-xs text-gojo-secondary">3D VRM Model</span>
        </div>
        <p className="text-xs text-gojo-secondary mt-1">
          Professional male with white hair and crystal blue eyes, confident
          voice with TTS lip-sync
        </p>
      </div>

      {/* 3D Avatar Display */}
      <div className="w-full h-80 rounded-xl overflow-hidden border border-white/10 bg-gradient-to-b from-crystal-500/5 to-ink/20">
        <GojoAvatar3D
          ref={avatarRef}
          speaking={speaking}
          onReady={() => console.log('Gojo avatar ready')}
          onSpeaking={speaking => setSpeaking(speaking)}
          onAnimationComplete={() => console.log('Animation complete')}
          className="w-full h-full"
        />
      </div>

      {/* Avatar Controls */}
      <div className="space-y-2">
        <button
          className="w-full bg-crystal-500/20 hover:bg-crystal-500/30 text-gojo-primary border border-crystal-500/30 rounded-lg px-4 py-2 transition-colors disabled:opacity-50"
          onClick={() =>
            onTalk(
              "Hello! I'm Gojo, representing Jimmie Coleman's portfolio. I specialize in DevSecOps with advanced CI/CD pipelines, Kubernetes orchestration, and security-first development practices. I'm excited to discuss the LinkOps AI-BOX project and how it revolutionizes enterprise AI deployment."
            )
          }
          disabled={speaking}
        >
          {speaking ? '🎤 Speaking...' : '▶️ Play Introduction'}
        </button>

        <button
          className="w-full bg-gold-500/20 hover:bg-gold-500/30 text-gojo-primary border border-gold-500/30 rounded-lg px-4 py-2 transition-colors disabled:opacity-50"
          onClick={() =>
            onTalk(
              'The LinkOps AI-BOX uses dual-speed CI/CD workflows with content deployment in under 2 minutes and full pipeline completion in 10 minutes. This enables instant knowledge updates for enterprise AI systems while maintaining security-first practices and over 90% golden set accuracy.'
            )
          }
          disabled={speaking}
        >
          {speaking ? '🎤 Speaking...' : '🎬 Ask About Projects'}
        </button>

        {speechUrl && (
          <div className="mt-3">
            <audio
              controls
              src={speechUrl}
              className="w-full"
              onEnded={() => {
                URL.revokeObjectURL(speechUrl);
                setSpeechUrl('');
              }}
            />
          </div>
        )}
      </div>
    </div>
  );
}
