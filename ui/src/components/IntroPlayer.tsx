import { useState } from 'react';

export default function IntroPlayer() {
  const [playing, setPlaying] = useState(false);

  const play = async () => {
    try {
      const a = new Audio('/intro.mp3');
      await a.play();
      setPlaying(true);
      a.onended = () => setPlaying(false);
    } catch (e) {
      console.error('Intro playback failed:', e);
      alert('Intro audio not available yet.');
    }
  };

  return (
    <button onClick={play} className="px-4 py-2 rounded-xl shadow">
      {playing ? '▶️ Playing…' : '▶️ Play Introduction'}
    </button>
  );
}