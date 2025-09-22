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

      // Scene setup - Gojo Domain Expansion vibes
      const scene = new THREE.Scene();

      // Dark purple gradient background (Domain Expansion feel)
      const canvas = document.createElement('canvas');
      canvas.width = 512;
      canvas.height = 512;
      const ctx = canvas.getContext('2d')!;
      const gradient = ctx.createLinearGradient(0, 0, 0, 512);
      gradient.addColorStop(0, '#1a0033'); // Deep purple top
      gradient.addColorStop(0.5, '#0d001a'); // Darker middle
      gradient.addColorStop(1, '#000000'); // Black bottom
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, 512, 512);

      const bgTexture = new THREE.CanvasTexture(canvas);
      scene.background = bgTexture;
      sceneRef.current = scene;

      // Camera setup - closer for Gojo focus
      const camera = new THREE.PerspectiveCamera(
        35,
        containerRef.current.clientWidth / containerRef.current.clientHeight,
        0.1,
        20
      );
      camera.position.set(0, 1.5, 2.2);
      camera.lookAt(0, 1.3, 0);
      cameraRef.current = camera;

      // Renderer setup with bloom capability
      const renderer = new THREE.WebGLRenderer({
        antialias: true,
        alpha: true,
        powerPreference: 'high-performance',
      });
      renderer.setSize(
        containerRef.current.clientWidth,
        containerRef.current.clientHeight
      );
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.shadowMap.enabled = true;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.0;
      rendererRef.current = renderer;

      // Lighting setup for Gojo aesthetic
      const ambientLight = new THREE.AmbientLight(0x6666ff, 0.4); // Subtle blue ambient
      scene.add(ambientLight);

      // Main light with blue tint
      const directionalLight = new THREE.DirectionalLight(0xffffff, 0.7);
      directionalLight.position.set(0.5, 2, 1);
      directionalLight.castShadow = true;
      scene.add(directionalLight);

      // Blue rim light for "Six Eyes" glow effect
      const rimLight = new THREE.DirectionalLight(0x00d4ff, 0.6);
      rimLight.position.set(-1, 1, -1);
      scene.add(rimLight);

      // Face key light
      const keyLight = new THREE.DirectionalLight(0xffffff, 0.4);
      keyLight.position.set(0, 2, 2);
      scene.add(keyLight);

      containerRef.current.appendChild(renderer.domElement);

      // Load Gojo VRM avatar
      loadAvatar();
    }, []);

    // Load VRM avatar
    const loadAvatar = async () => {
      try {
        // Try to load actual Gojo VRM model
        const { GLTFLoader } = await import(
          'three/examples/jsm/loaders/GLTFLoader'
        );
        const loader = new GLTFLoader();

        // Load Gojo VRM from public assets
        loader.load(
          '/avatars/gojo.vrm', // You'll need to add the Gojo VRM file here
          async gltf => {
            try {
              // Convert GLTF to VRM
              const vrm = await VRM.from(gltf);

              // Add to scene
              if (sceneRef.current) {
                sceneRef.current.add(vrm.scene);

                // Position and scale the avatar
                vrm.scene.position.y = -1;
                vrm.scene.scale.set(1, 1, 1);

                // Store VRM reference
                vrmRef.current = vrm;

                // Setup viseme mappings for Gojo
                setupGojoVisemeMapping(vrm);

                console.log('✅ Gojo VRM loaded successfully');
                setIsLoading(false);
                onReady?.();
              }
            } catch (vrmError) {
              console.error('VRM conversion failed:', vrmError);
              createFallbackAvatar();
              setIsLoading(false);
            }
          },
          progress => {
            console.log(
              'Loading Gojo VRM:',
              ((progress.loaded / progress.total) * 100).toFixed(0) + '%'
            );
          },
          error => {
            console.error('Failed to load Gojo VRM:', error);
            console.log('Using enhanced fallback avatar');
            createFallbackAvatar();
            setIsLoading(false);
          }
        );
      } catch (err) {
        console.error('GLTFLoader import failed:', err);
        createFallbackAvatar();
        setIsLoading(false);
      }
    };

    // Create improved Gojo programmatic avatar
    const createFallbackAvatar = () => {
      if (!sceneRef.current) return;

      // Create anime-style Gojo
      const gojo = new THREE.Group();

      // Create toon gradient for anime shading
      const colors = new Uint8Array([0, 127, 255]);
      const gradientMap = new THREE.DataTexture(
        colors,
        colors.length,
        1,
        THREE.LuminanceFormat
      );
      gradientMap.needsUpdate = true;

      // Head with anime proportions (slightly elongated)
      const headGeometry = new THREE.BoxGeometry(0.4, 0.5, 0.35, 2, 2, 2);
      // Round the edges
      headGeometry.translate(0, 0, 0.05);
      const positions = headGeometry.attributes.position;
      for (let i = 0; i < positions.count; i++) {
        const x = positions.getX(i);
        const y = positions.getY(i);
        const z = positions.getZ(i);
        const distance = Math.sqrt(x * x + y * y * 0.7);
        if (distance > 0.18) {
          positions.setX(i, x * 0.85);
          positions.setZ(i, z * 0.9);
        }
      }

      const headMaterial = new THREE.MeshToonMaterial({
        color: 0xffe4d6,
        gradientMap: gradientMap,
      });
      const head = new THREE.Mesh(headGeometry, headMaterial);
      head.position.y = 1.6;
      gojo.add(head);

      // Create signature Gojo spiky white hair
      const hairMaterial = new THREE.MeshToonMaterial({
        color: 0xf8f8ff,
        gradientMap: gradientMap,
      });

      // Multiple hair spikes for anime look
      const spikeData = [
        { pos: [0, 1.95, 0], scale: [0.35, 0.35, 0.3], rot: [0, 0, 0] },
        { pos: [-0.15, 1.9, 0.05], scale: [0.2, 0.3, 0.2], rot: [0, 0, -0.3] },
        { pos: [0.15, 1.9, 0.05], scale: [0.2, 0.3, 0.2], rot: [0, 0, 0.3] },
        { pos: [0, 2.0, -0.1], scale: [0.25, 0.25, 0.2], rot: [-0.2, 0, 0] },
        {
          pos: [-0.1, 1.92, -0.12],
          scale: [0.15, 0.25, 0.15],
          rot: [-0.3, -0.2, -0.2],
        },
        {
          pos: [0.1, 1.92, -0.12],
          scale: [0.15, 0.25, 0.15],
          rot: [-0.3, 0.2, 0.2],
        },
        {
          pos: [-0.08, 1.88, 0.12],
          scale: [0.18, 0.22, 0.15],
          rot: [0.2, -0.1, -0.15],
        },
        {
          pos: [0.08, 1.88, 0.12],
          scale: [0.18, 0.22, 0.15],
          rot: [0.2, 0.1, 0.15],
        },
      ];

      spikeData.forEach(spike => {
        const geometry = new THREE.ConeGeometry(...spike.scale.slice(0, 2), 5);
        const mesh = new THREE.Mesh(geometry, hairMaterial);
        mesh.position.set(...spike.pos);
        mesh.rotation.set(...spike.rot);
        gojo.add(mesh);
      });

      // Eyes (bright blue/white glow effect)
      const eyeMaterial = new THREE.MeshBasicMaterial({
        color: 0x00d4ff,
        transparent: true,
        opacity: 0.9,
      });

      const eyeGeometry = new THREE.SphereGeometry(0.04, 16, 16);
      const leftEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
      leftEye.position.set(-0.08, 1.62, 0.15);
      leftEye.scale.set(1.2, 0.7, 1); // Anime eye shape
      gojo.add(leftEye);

      const rightEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
      rightEye.position.set(0.08, 1.62, 0.15);
      rightEye.scale.set(1.2, 0.7, 1); // Anime eye shape
      gojo.add(rightEye);

      // Eye glow effect
      const glowMaterial = new THREE.MeshBasicMaterial({
        color: 0x00d4ff,
        transparent: true,
        opacity: 0.3,
      });
      const glowGeometry = new THREE.SphereGeometry(0.06, 16, 16);

      const leftGlow = new THREE.Mesh(glowGeometry, glowMaterial);
      leftGlow.position.copy(leftEye.position);
      gojo.add(leftGlow);

      const rightGlow = new THREE.Mesh(glowGeometry, glowMaterial);
      rightGlow.position.copy(rightEye.position);
      gojo.add(rightGlow);

      // Mouth (anime style line)
      const mouthGeometry = new THREE.BoxGeometry(0.06, 0.008, 0.01);
      const mouthMaterial = new THREE.MeshLambertMaterial({ color: 0x2d3748 });
      const mouth = new THREE.Mesh(mouthGeometry, mouthMaterial);
      mouth.position.set(0, 1.52, 0.17);
      gojo.add(mouth);

      // High collar Jujutsu uniform
      const bodyGeometry = new THREE.CylinderGeometry(0.28, 0.32, 1.0, 8);
      const bodyMaterial = new THREE.MeshToonMaterial({
        color: 0x0a0a0a,
        gradientMap: gradientMap,
      });
      const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
      body.position.y = 0.8;
      gojo.add(body);

      // High collar detail
      const collarGeometry = new THREE.CylinderGeometry(0.18, 0.22, 0.15, 8);
      const collar = new THREE.Mesh(collarGeometry, bodyMaterial);
      collar.position.y = 1.35;
      gojo.add(collar);

      // Store references for animations
      (gojo as any).leftEye = leftEye;
      (gojo as any).rightEye = rightEye;
      (gojo as any).mouth = mouth;
      (gojo as any).head = head;

      sceneRef.current.add(gojo);
      console.log('🎌 High-quality Gojo programmatic avatar created');
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
        const audioType = ttsData.audio_base64.startsWith('UklGR')
          ? 'audio/wav'
          : 'audio/mp3';
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

    // Setup Gojo-specific viseme mappings
    const setupGojoVisemeMapping = (vrm: VRM) => {
      // Store expression names for Gojo model
      console.log('Setting up Gojo viseme mappings');

      // Common VRM expression names that Gojo models use
      const expressions = vrm.expressionManager;
      if (expressions) {
        // Log available expressions for debugging
        const availableExpressions = Object.keys(
          expressions.expressionMap || {}
        );
        console.log('Available Gojo expressions:', availableExpressions);
      }
    };

    // Map blendshape names to VRM expressions (Gojo-optimized)
    const mapToVRMExpression = (shapeName: string): string | null => {
      // Mapping for typical Gojo VRM models
      const mapping: Record<string, string> = {
        // Vowel visemes
        A: 'aa', // あ
        I: 'ih', // い
        U: 'ou', // う
        E: 'ee', // え
        O: 'oh', // お

        // Mouth controls
        jawOpen: 'mouth_open',

        // Additional expressions for Gojo
        smile: 'happy',
        smirk: 'relaxed',
        serious: 'neutral',

        // Eye controls (Six Eyes effect)
        blink: 'blink',
        blinkLeft: 'blinkLeft',
        blinkRight: 'blinkRight',
      };

      // Try multiple possible names (VRM models vary)
      return (
        mapping[shapeName] ||
        mapping[shapeName.toLowerCase()] ||
        shapeName.toLowerCase() ||
        null
      );
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
