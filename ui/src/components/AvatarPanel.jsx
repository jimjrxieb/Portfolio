import { useState } from 'react';

export default function AvatarPanel({ script }) {
  const [isPlaying, setIsPlaying] = useState(false);

  const handlePlay = () => {
    setIsPlaying(!isPlaying);
    // Avatar playback would be implemented here
  };

  return (
    <div className="panel">
      <h3>James Avatar</h3>
      <div className="avatar-placeholder">
        👨‍💻
      </div>
      <div className="intro-text">
        {script}
      </div>
      <button 
        className="send-button" 
        onClick={handlePlay}
        style={{ marginTop: '10px' }}
      >
        {isPlaying ? '⏸️ Pause' : '▶️ Play Introduction'}
      </button>
    </div>
  );
}