/**
 * 2D Talking Head Component - Real-time sprite-based lip sync
 * Much more reliable than 3D for interviews!
 */

import React, { useState, useRef, useEffect, useCallback } from 'react';

interface VisemeData {
  audio_offset: number;
  viseme_id: number;
  blendshapes: Record<string, number>;
  phoneme: string;
}

interface TTSData {
  audio_base64: string;
  visemes: VisemeData[];
  duration_ms: number;
}

interface TalkingHeadProps {
  onReady?: () => void;
  onSpeaking?: (speaking: boolean) => void;
  className?: string;
  speaking?: boolean;
  onAnimationComplete?: () => void;
}

export interface TalkingHeadRef {
  speak: (ttsData: TTSData) => Promise<void>;
  updateHairColor: (color: string) => void;
  updateEyeColor: (color: string) => void;
  updateOutfitColor: (color: string) => void;
}

// Mouth frame mapping for different sounds
const MOUTH_FRAMES = {
  closed: '😐',
  A: '😮', // Open mouth (ah)
  E: '😊', // Slight smile (eh)
  I: '😊', // Narrow smile (ee)
  O: '😲', // Round mouth (oh)
  U: '😗', // Pursed lips (oo)
} as const;

export const TalkingHead = React.forwardRef<TalkingHeadRef, TalkingHeadProps>(
  (
    {
      onReady,
      onSpeaking,
      className = '',
      speaking = false,
      onAnimationComplete,
    },
    ref
  ) => {
    const [currentMouth, setCurrentMouth] =
      useState<keyof typeof MOUTH_FRAMES>('closed');
    const [isBlinking, setIsBlinking] = useState(false);
    const [headTilt, setHeadTilt] = useState(0);
    const [eyePosition, setEyePosition] = useState({ x: 0, y: 0 });
    const [isSpeaking, setIsSpeaking] = useState(false);

    const blinkTimerRef = useRef<NodeJS.Timeout>();
    const headSwayRef = useRef<NodeJS.Timeout>();
    const eyeDartRef = useRef<NodeJS.Timeout>();
    const speechTimeoutRef = useRef<NodeJS.Timeout>();

    // Blink animation (every 2-4 seconds)
    const startBlinking = useCallback(() => {
      const blink = () => {
        if (!isSpeaking || Math.random() > 0.7) {
          // Reduce blinks while speaking
          setIsBlinking(true);
          setTimeout(() => setIsBlinking(false), 150); // 150ms blink
        }

        const nextBlink = 2000 + Math.random() * 2000; // 2-4 seconds
        blinkTimerRef.current = setTimeout(blink, nextBlink);
      };
      blink();
    }, [isSpeaking]);

    // Head sway animation (subtle)
    const startHeadSway = useCallback(() => {
      const sway = () => {
        const newTilt = (Math.random() - 0.5) * 4; // ±2 degrees
        setHeadTilt(newTilt);

        const nextSway = 3000 + Math.random() * 2000; // 3-5 seconds
        headSwayRef.current = setTimeout(sway, nextSway);
      };
      sway();
    }, []);

    // Eye dart animation (micro saccades)
    const startEyeDarts = useCallback(() => {
      const dart = () => {
        if (!isSpeaking) {
          // Only dart when not speaking
          const newX = (Math.random() - 0.5) * 6; // ±3px
          const newY = (Math.random() - 0.5) * 4; // ±2px
          setEyePosition({ x: newX, y: newY });

          // Return to center after a moment
          setTimeout(() => setEyePosition({ x: 0, y: 0 }), 800);
        }

        const nextDart = 4000 + Math.random() * 3000; // 4-7 seconds
        eyeDartRef.current = setTimeout(dart, nextDart);
      };
      dart();
    }, [isSpeaking]);

    // Viseme mapping with smoothing
    const processVisemes = useCallback(
      (visemes: VisemeData[]) => {
        let currentIndex = 0;
        const startTime = Date.now();

        const animate = () => {
          const elapsed = Date.now() - startTime;

          // Find current viseme
          while (
            currentIndex < visemes.length - 1 &&
            elapsed >= visemes[currentIndex + 1].audio_offset
          ) {
            currentIndex++;
          }

          if (currentIndex < visemes.length) {
            const viseme = visemes[currentIndex];

            // Map phonemes to mouth shapes with smoothing
            let mouthShape: keyof typeof MOUTH_FRAMES = 'closed';

            switch (viseme.phoneme?.toUpperCase()) {
              case 'A':
              case 'AA':
              case 'AH':
                mouthShape = 'A';
                break;
              case 'E':
              case 'EH':
              case 'ER':
                mouthShape = 'E';
                break;
              case 'I':
              case 'IH':
              case 'IY':
                mouthShape = 'I';
                break;
              case 'O':
              case 'OH':
              case 'AO':
                mouthShape = 'O';
                break;
              case 'U':
              case 'UH':
              case 'UW':
                mouthShape = 'U';
                break;
              default:
                mouthShape = 'closed';
            }

            setCurrentMouth(mouthShape);

            // Continue animation
            if (currentIndex < visemes.length - 1) {
              const nextOffset = visemes[currentIndex + 1].audio_offset;
              const delay = Math.max(16, nextOffset - elapsed); // Min 16ms (60fps)
              speechTimeoutRef.current = setTimeout(animate, delay);
            } else {
              // Speech finished
              setTimeout(() => {
                setCurrentMouth('closed');
                setIsSpeaking(false);
                onSpeaking?.(false);
                onAnimationComplete?.();
              }, 300);
            }
          }
        };

        animate();
      },
      [onSpeaking, onAnimationComplete]
    );

    // Speak function
    const speak = useCallback(
      async (ttsData: TTSData) => {
        setIsSpeaking(true);
        onSpeaking?.(true);

        if (ttsData.visemes && ttsData.visemes.length > 0) {
          processVisemes(ttsData.visemes);
        } else {
          // Fallback: simple mouth animation
          const duration = ttsData.duration_ms;
          let elapsed = 0;

          const simpleTalk = () => {
            elapsed += 150;
            const frames: (keyof typeof MOUTH_FRAMES)[] = [
              'A',
              'E',
              'I',
              'O',
              'U',
              'closed',
            ];
            const frame = frames[Math.floor((elapsed / 150) % frames.length)];
            setCurrentMouth(frame);

            if (elapsed < duration) {
              speechTimeoutRef.current = setTimeout(simpleTalk, 150);
            } else {
              setCurrentMouth('closed');
              setIsSpeaking(false);
              onSpeaking?.(false);
              onAnimationComplete?.();
            }
          };

          simpleTalk();
        }
      },
      [processVisemes, onSpeaking, onAnimationComplete]
    );

    // Color customization (for future use)
    const updateHairColor = useCallback((color: string) => {
      // TODO: Apply CSS filters to change hair color
      // Development only logging
      if (process.env.NODE_ENV === 'development') {
        console.log('Hair color:', color);
      }
    }, []);

    const updateEyeColor = useCallback((color: string) => {
      // TODO: Apply CSS filters to change eye color
      // Development only logging
      if (process.env.NODE_ENV === 'development') {
        console.log('Eye color:', color);
      }
    }, []);

    const updateOutfitColor = useCallback((color: string) => {
      // TODO: Apply CSS filters to change outfit color
      // Development only logging
      if (process.env.NODE_ENV === 'development') {
        console.log('Outfit color:', color);
      }
    }, []);

    // Setup animations on mount
    useEffect(() => {
      startBlinking();
      startHeadSway();
      startEyeDarts();
      onReady?.();

      return () => {
        if (blinkTimerRef.current) clearTimeout(blinkTimerRef.current);
        if (headSwayRef.current) clearTimeout(headSwayRef.current);
        if (eyeDartRef.current) clearTimeout(eyeDartRef.current);
        if (speechTimeoutRef.current) clearTimeout(speechTimeoutRef.current);
      };
    }, [startBlinking, startHeadSway, startEyeDarts, onReady]);

    // Expose methods via ref
    React.useImperativeHandle(
      ref,
      () => ({
        speak,
        updateHairColor,
        updateEyeColor,
        updateOutfitColor,
      }),
      [speak, updateHairColor, updateEyeColor, updateOutfitColor]
    );

    return (
      <div className={`relative flex items-center justify-center ${className}`}>
        {/* Avatar Container with animations */}
        <div
          className="relative transition-all duration-500 ease-in-out"
          style={{
            transform: `rotate(${headTilt}deg)`,
          }}
        >
          {/* Base Avatar Image */}
          <div className="relative w-64 h-64 mx-auto">
            {/* Background Circle */}
            <div className="absolute inset-0 bg-gradient-to-b from-crystal-500/10 to-ink/20 rounded-full border border-white/10" />

            {/* Avatar Face */}
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-8xl relative">
                {/* Base Face */}
                <span className="relative">
                  👨‍💼
                  {/* Eyes with micro-movements */}
                  <span
                    className="absolute text-2xl transition-all duration-200"
                    style={{
                      left: '18px',
                      top: '20px',
                      transform: `translate(${eyePosition.x}px, ${eyePosition.y}px)`,
                      opacity: isBlinking ? 0 : 1,
                    }}
                  >
                    👁️
                  </span>
                  <span
                    className="absolute text-2xl transition-all duration-200"
                    style={{
                      right: '18px',
                      top: '20px',
                      transform: `translate(${-eyePosition.x}px, ${eyePosition.y}px)`,
                      opacity: isBlinking ? 0 : 1,
                    }}
                  >
                    👁️
                  </span>
                  {/* Mouth with lip-sync */}
                  <span
                    className="absolute text-3xl transition-all duration-75"
                    style={{
                      left: '50%',
                      top: '45px',
                      transform: 'translateX(-50%)',
                    }}
                  >
                    {MOUTH_FRAMES[currentMouth]}
                  </span>
                </span>
              </div>
            </div>

            {/* Glow effect when speaking */}
            {isSpeaking && (
              <div className="absolute inset-0 rounded-full bg-gojo-primary/20 animate-pulse" />
            )}
          </div>

          {/* Status indicator */}
          <div className="absolute -bottom-4 left-1/2 transform -translate-x-1/2">
            <div
              className={`px-3 py-1 rounded-full text-xs font-medium transition-all ${
                isSpeaking
                  ? 'bg-green-500/20 text-green-300 border border-green-500/30'
                  : 'bg-crystal-500/20 text-gojo-secondary border border-white/10'
              }`}
            >
              {isSpeaking ? '🎤 Speaking...' : '💬 Ready'}
            </div>
          </div>
        </div>
      </div>
    );
  }
);

export default TalkingHead;
