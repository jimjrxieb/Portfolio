import React, { useState, useRef } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Button,
  IconButton,
  Box,
  Stack,
  Chip,
  Divider,
} from '@mui/material';
import {
  VolumeOff,
  VolumeUp,
  PlayArrow,
  Movie,
  Mic,
} from '@mui/icons-material';
import { API_BASE } from '../lib/api';
import GojoAvatar3D, { GojoAvatar3DRef } from './GojoAvatar3D';

export default function AvatarPanel() {
  const [speaking, setSpeaking] = useState(false);
  const [speechUrl, setSpeechUrl] = useState<string>('');
  const [muted, setMuted] = useState(false);
  const avatarRef = useRef<GojoAvatar3DRef>(null);

  async function onTalk(text: string) {
    if (muted) return; // Don't speak if muted

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
      const audioType = data.audio_base64.startsWith('UklGR')
        ? 'audio/wav'
        : 'audio/mp3';
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
    <Stack spacing={3} data-dev="avatar-panel">
      {/* Avatar Info Display */}
      <Card
        elevation={2}
        sx={{
          bgcolor: 'rgba(255, 255, 255, 0.02)',
          backdropFilter: 'blur(10px)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
        }}
      >
        <CardContent sx={{ pb: 2 }}>
          <Box
            display="flex"
            alignItems="center"
            justifyContent="space-between"
            mb={1}
          >
            <Box display="flex" alignItems="center" gap={1}>
              <Typography variant="body2" fontWeight={500} color="primary">
                Avatar: Jade
              </Typography>
              <Typography variant="body2" color="text.secondary">
                •
              </Typography>
              <Chip
                label="3D VRM Model"
                size="small"
                variant="outlined"
                sx={{ height: 20, fontSize: '0.75rem' }}
              />
            </Box>
            <IconButton
              onClick={() => setMuted(!muted)}
              size="small"
              color={muted ? 'error' : 'default'}
              title={muted ? 'Unmute Audio' : 'Mute Audio'}
            >
              {muted ? <VolumeOff /> : <VolumeUp />}
            </IconButton>
          </Box>
          <Typography variant="caption" color="text.secondary">
            AI assistant with interactive speech and visual responses
          </Typography>
        </CardContent>
      </Card>

      {/* 3D Avatar Display */}
      <Card
        elevation={3}
        sx={{
          height: 320,
          overflow: 'hidden',
          background:
            'linear-gradient(180deg, rgba(139, 92, 246, 0.05) 0%, rgba(17, 24, 39, 0.2) 100%)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
        }}
      >
        <GojoAvatar3D
          ref={avatarRef}
          speaking={speaking}
          onReady={() => console.log('Jade avatar ready')}
          onSpeaking={speaking => setSpeaking(speaking)}
          onAnimationComplete={() => console.log('Animation complete')}
          className="w-full h-full"
        />
      </Card>

      {/* Avatar Controls */}
      <Stack spacing={2}>
        <Button
          variant="contained"
          size="large"
          startIcon={speaking ? <Mic /> : <PlayArrow />}
          onClick={() =>
            onTalk(
              "Welcome to Jimmie's portfolio page! I'm Jade, Jimmie's AI assistant. He is CKA and CompTIA Security Plus certified with a deep passion for AI and built this platform using it. He is currently working on 3 LinkOps AI-BOX projects for 3 separate clients. Ask anything in the chatbox and I'll try my best to answer them."
            )
          }
          disabled={speaking}
          sx={{
            bgcolor: 'rgba(139, 92, 246, 0.2)',
            borderColor: 'rgba(139, 92, 246, 0.3)',
            color: 'primary.main',
            '&:hover': {
              bgcolor: 'rgba(139, 92, 246, 0.3)',
            },
          }}
        >
          {speaking ? 'Speaking...' : 'Play Introduction'}
        </Button>

        <Button
          variant="outlined"
          size="large"
          startIcon={speaking ? <Mic /> : <Movie />}
          onClick={() =>
            onTalk(
              'Jimmie built this entire platform combining his DevSecOps expertise with AI passion. He created three LinkOps AI-BOX solutions: one for enterprise deployment, ZRS-COPILOT for property management, and GP-COPILOT for cybersecurity. Each leverages his skills in Docker, Kubernetes, GitHub Actions, and AI technologies like RAG systems and vector databases.'
            )
          }
          disabled={speaking}
          sx={{
            borderColor: 'rgba(251, 191, 36, 0.3)',
            color: 'primary.main',
            bgcolor: 'rgba(251, 191, 36, 0.1)',
            '&:hover': {
              bgcolor: 'rgba(251, 191, 36, 0.2)',
              borderColor: 'rgba(251, 191, 36, 0.4)',
            },
          }}
        >
          {speaking ? 'Speaking...' : 'About the Platform'}
        </Button>

        {speechUrl && (
          <Box mt={2}>
            <audio
              controls
              src={speechUrl}
              style={{ width: '100%' }}
              onEnded={() => {
                URL.revokeObjectURL(speechUrl);
                setSpeechUrl('');
              }}
            />
          </Box>
        )}
      </Stack>
    </Stack>
  );
}
