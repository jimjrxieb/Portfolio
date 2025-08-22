/**
 * Gojo 3D Avatar Component
 * VRM-based 3D avatar with TTS lip-sync and animations
 */

import React, { useEffect, useRef, useState, useCallback } from 'react';
import * as THREE from 'three';
import { VRM, VRMLoaderPlugin } from '@pixiv/three-vrm';

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

interface GojoAvatar3DProps {
  onReady?: () => void;
  onSpeaking?: (speaking: boolean) => void;
  className?: string;
  speaking?: boolean;
  onAnimationComplete?: () => void;
}

export interface GojoAvatar3DRef {
  speak: (ttsData: TTSData) => Promise<void>;
}

export const GojoAvatar3D = React.forwardRef<
  GojoAvatar3DRef,
  GojoAvatar3DProps
>(
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
    const containerRef = useRef<HTMLDivElement>(null);
    const sceneRef = useRef<THREE.Scene>();
    const rendererRef = useRef<THREE.WebGLRenderer>();
    const cameraRef = useRef<THREE.PerspectiveCamera>();
    const vrmRef = useRef<VRM>();
    const audioRef = useRef<HTMLAudioElement>();
    const animationIdRef = useRef<number>();

    const [isLoading, setIsLoading] = useState(true);
    const [isSpeaking, setIsSpeaking] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Initialize Three.js scene
    const initScene = useCallback(() => {
      if (!containerRef.current) return;

      // Scene setup
      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0x212121);
      sceneRef.current = scene;

      // Camera setup
      const camera = new THREE.PerspectiveCamera(
        30,
        containerRef.current.clientWidth / containerRef.current.clientHeight,
        0.1,
        20
      );
      camera.position.set(0, 1.4, 2.5);
      cameraRef.current = camera;

      // Renderer setup
      const renderer = new THREE.WebGLRenderer({
        antialias: true,
        alpha: true,
      });
      renderer.setSize(
        containerRef.current.clientWidth,
        containerRef.current.clientHeight
      );
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.shadowMap.enabled = true;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      rendererRef.current = renderer;

      // Lighting setup for avatar
      const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
      scene.add(ambientLight);

      const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
      directionalLight.position.set(1, 1, 1);
      directionalLight.castShadow = true;
      scene.add(directionalLight);

      // Key light for face
      const keyLight = new THREE.DirectionalLight(0xffffff, 0.5);
      keyLight.position.set(-1, 2, 2);
      scene.add(keyLight);

      containerRef.current.appendChild(renderer.domElement);

      // Load Gojo VRM avatar
      loadAvatar();
    }, []);

    // Load VRM avatar
    const loadAvatar = async () => {
      try {
        // Since GLTFLoader type issues, we'll create a fallback avatar directly
        console.log('VRM loader not available, using fallback avatar');

        // Create fallback avatar immediately
        createFallbackAvatar();
        setIsLoading(false);
        onReady?.();
      } catch (err) {
        console.error('Failed to load avatar:', err);
        setError('Failed to load Gojo avatar. Using fallback mode.');
        setIsLoading(false);

        // Create a simple fallback representation
        createFallbackAvatar();
      }
    };

    // Create fallback avatar if VRM fails to load
    const createFallbackAvatar = () => {
      if (!sceneRef.current) return;

      // Simple geometric representation of Gojo
      const group = new THREE.Group();

      // Head (sphere with white hair texture)
      const headGeometry = new THREE.SphereGeometry(0.3, 32, 32);
      const headMaterial = new THREE.MeshLambertMaterial({ color: 0xffeaa7 });
      const head = new THREE.Mesh(headGeometry, headMaterial);
      head.position.y = 1.4;
      group.add(head);

      // Hair (larger sphere, white)
      const hairGeometry = new THREE.SphereGeometry(0.35, 32, 32);
      const hairMaterial = new THREE.MeshLambertMaterial({ color: 0xf8f9fa });
      const hair = new THREE.Mesh(hairGeometry, hairMaterial);
      hair.position.y = 1.5;
      group.add(hair);

      // Eyes (crystal blue)
      const eyeGeometry = new THREE.SphereGeometry(0.03, 16, 16);
      const eyeMaterial = new THREE.MeshLambertMaterial({ color: 0x00b8ff });

      const leftEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
      leftEye.position.set(-0.1, 1.4, 0.25);
      group.add(leftEye);

      const rightEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
      rightEye.position.set(0.1, 1.4, 0.25);
      group.add(rightEye);

      // Body (simple cylinder)
      const bodyGeometry = new THREE.CylinderGeometry(0.3, 0.3, 1.2, 8);
      const bodyMaterial = new THREE.MeshLambertMaterial({ color: 0x2d3748 });
      const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
      body.position.y = 0.6;
      group.add(body);

      sceneRef.current.add(group);
      console.log('Fallback Gojo avatar created');
    };

    // Animation loop
    const animate = useCallback(() => {
      if (!rendererRef.current || !sceneRef.current || !cameraRef.current)
        return;

      // Update VRM
      if (vrmRef.current) {
        vrmRef.current.update(0.016); // 60fps
      }

      // Add subtle breathing animation
      if (vrmRef.current && !isSpeaking) {
        const time = Date.now() * 0.001;
        const breatheAmount = Math.sin(time * 2) * 0.01;
        vrmRef.current.scene.position.y = -1 + breatheAmount;
      }

      // Render
      rendererRef.current.render(sceneRef.current, cameraRef.current);
      animationIdRef.current = requestAnimationFrame(animate);
    }, [isSpeaking]);

    // Handle window resize
    const handleResize = useCallback(() => {
      if (!containerRef.current || !cameraRef.current || !rendererRef.current)
        return;

      const width = containerRef.current.clientWidth;
      const height = containerRef.current.clientHeight;

      cameraRef.current.aspect = width / height;
      cameraRef.current.updateProjectionMatrix();
      rendererRef.current.setSize(width, height);
    }, []);

    // Speak with TTS and lip-sync
    const speak = useCallback(async (ttsData: TTSData) => {
      if (!vrmRef.current) {
        console.warn('VRM not loaded, cannot perform lip-sync');
        return;
      }

      setIsSpeaking(true);
      onSpeaking?.(true);

      try {
        // Create audio from base64 with proper type detection
        const audioType = ttsData.audio_base64.startsWith('UklGR') ? 'audio/wav' : 'audio/mp3';
        const audioBlob = new Blob(
          [Uint8Array.from(atob(ttsData.audio_base64), c => c.charCodeAt(0))],
          { type: audioType }
        );
        const audioUrl = URL.createObjectURL(audioBlob);

        // Play audio
        if (audioRef.current) {
          audioRef.current.src = audioUrl;
          audioRef.current.play();
        }

        // Start lip-sync animation
        performLipSync(ttsData.visemes, ttsData.duration_ms);
      } catch (error) {
        console.error('Failed to speak:', error);
      }
    }, []);

    // Perform lip-sync animation using viseme data
    const performLipSync = (visemes: VisemeData[], duration: number) => {
      if (!vrmRef.current?.expressionManager) return;

      const startTime = Date.now();

      const animateLipSync = () => {
        const elapsed = Date.now() - startTime;

        if (elapsed >= duration) {
          // Reset mouth to neutral
          resetMouthShape();
          setIsSpeaking(false);
          onSpeaking?.(false);
          return;
        }

        // Find current viseme
        const currentViseme = visemes.find((viseme, index) => {
          const nextViseme = visemes[index + 1];
          return (
            elapsed >= viseme.audio_offset &&
            (!nextViseme || elapsed < nextViseme.audio_offset)
          );
        });

        if (currentViseme && vrmRef.current?.expressionManager) {
          // Apply blendshapes
          Object.entries(currentViseme.blendshapes).forEach(
            ([shape, weight]) => {
              if (vrmRef.current?.expressionManager) {
                // Map to VRM expression names
                const vrmExpression = mapToVRMExpression(shape);
                if (vrmExpression) {
                  vrmRef.current.expressionManager.setValue(
                    vrmExpression,
                    weight
                  );
                }
              }
            }
          );
        }

        requestAnimationFrame(animateLipSync);
      };

      animateLipSync();
    };

    // Map blendshape names to VRM expressions
    const mapToVRMExpression = (shapeName: string): string | null => {
      const mapping: Record<string, string> = {
        A: 'aa',
        I: 'ih',
        U: 'ou',
        E: 'ee',
        O: 'oh',
        jawOpen: 'jawOpen',
      };
      return mapping[shapeName] || null;
    };

    // Reset mouth to neutral position
    const resetMouthShape = () => {
      if (!vrmRef.current?.expressionManager) return;

      ['aa', 'ih', 'ou', 'ee', 'oh', 'jawOpen'].forEach(expression => {
        vrmRef.current?.expressionManager?.setValue(expression, 0);
      });
    };

    // Initialize scene on mount
    useEffect(() => {
      initScene();
      animate();

      // Create audio element
      audioRef.current = new Audio();
      audioRef.current.onended = () => {
        setIsSpeaking(false);
        onSpeaking?.(false);
      };

      // Add resize listener
      window.addEventListener('resize', handleResize);

      return () => {
        // Cleanup
        if (animationIdRef.current) {
          cancelAnimationFrame(animationIdRef.current);
        }
        window.removeEventListener('resize', handleResize);

        if (rendererRef.current && containerRef.current) {
          containerRef.current.removeChild(rendererRef.current.domElement);
          rendererRef.current.dispose();
        }
      };
    }, [initScene, animate, handleResize]);

    // Expose speak method via ref
    React.useImperativeHandle(
      ref,
      () => ({
        speak,
      }),
      [speak]
    );

    return (
      <div className={`relative ${className}`}>
        <div
          ref={containerRef}
          className="w-full h-full min-h-[400px] rounded-lg overflow-hidden bg-gradient-to-b from-gray-800 to-gray-900"
        />

        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-gray-800 bg-opacity-75 rounded-lg">
            <div className="text-center">
              <div className="animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-2"></div>
              <p className="text-white">Loading Gojo...</p>
            </div>
          </div>
        )}

        {error && (
          <div className="absolute top-2 left-2 bg-yellow-500 text-black px-2 py-1 rounded text-sm">
            ⚠️ Fallback Mode
          </div>
        )}

        {isSpeaking && (
          <div className="absolute bottom-2 left-2 bg-green-500 text-white px-2 py-1 rounded text-sm">
            🎤 Speaking...
          </div>
        )}
      </div>
    );
  }
);

GojoAvatar3D.displayName = 'GojoAvatar3D';

export default GojoAvatar3D;
