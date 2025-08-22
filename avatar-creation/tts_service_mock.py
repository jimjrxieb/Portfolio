"""
Mock TTS Service for Testing
Simulates Azure TTS with viseme support for development/testing
"""

import base64
import json
import asyncio
from typing import List, Dict, Optional
import os
from datetime import datetime
import random

class MockTTSService:
    """Mock TTS service that simulates Azure Speech with visemes"""
    
    def __init__(self):
        self.voice_name = "en-US-DavisNeural"
        print("🔧 Mock TTS Service initialized (Azure SDK not available)")
    
    async def synthesize_with_visemes(self, text: str) -> Dict:
        """
        Mock synthesis that returns fake audio and viseme data
        """
        # Simulate processing time
        await asyncio.sleep(0.1)
        
        # Generate mock viseme data based on text length
        words = text.split()
        visemes = []
        audio_offset = 0
        
        for word in words:
            # Generate visemes for each character/sound
            for i, char in enumerate(word.lower()):
                viseme_data = self._char_to_viseme(char)
                if viseme_data:
                    visemes.append({
                        "audio_offset": audio_offset,
                        "viseme_id": viseme_data["id"],
                        "blendshapes": viseme_data["blendshapes"],
                        "phoneme": viseme_data["phoneme"]
                    })
                audio_offset += 150  # 150ms per sound
            
            # Add pause between words
            audio_offset += 100
        
        # Use actual intro.mp3 file instead of silent audio
        duration_ms = audio_offset
        sample_rate = 16000
        
        try:
            # Generate a pleasant voice-like tone sequence
            import struct
            import math
            
            # Create WAV file header + audio data
            samples = int(duration_ms * sample_rate / 1000)
            
            # Generate simple notification instead of weird speech sounds
            audio_samples = []
            notification_duration = min(1.0, duration_ms / 1000)  # Max 1 second
            actual_samples = int(notification_duration * sample_rate)
            
            for i in range(actual_samples):
                t = i / sample_rate
                
                # Simple pleasant notification tone (like a soft chime)
                freq = 800  # Single clean frequency
                envelope = math.sin(t * math.pi / notification_duration)  # Natural fade in/out
                final_sample = envelope * 0.2 * math.sin(2 * math.pi * freq * t)  # Quieter
                
                # Convert to 16-bit integer
                int_sample = int(max(-32767, min(32767, final_sample * 32767)))
                audio_samples.append(struct.pack('<h', int_sample))
            
            # Create a simple WAV file
            audio_data = b''.join(audio_samples)
            
            # WAV header
            wav_header = struct.pack('<4sI4s4sIHHIIHH4sI',
                b'RIFF', 36 + len(audio_data), b'WAVE', b'fmt ', 16,
                1, 1, sample_rate, sample_rate * 2, 2, 16,
                b'data', len(audio_data))
            
            wav_data = wav_header + audio_data
            audio_base64 = base64.b64encode(wav_data).decode('utf-8')
            print("🔔 Generated notification chime (TTS not available)")
            
        except Exception as e:
            print(f"⚠️ Audio generation failed: {e}, using minimal tone")
            # Simple fallback - short beep
            audio_data = b'\x00\x01' * 8000  # Very short audio
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
        
        return {
            "audio_base64": audio_base64,
            "visemes": visemes,
            "duration_ms": duration_ms,
            "sample_rate": sample_rate,
            "voice": self.voice_name,
            "timestamp": datetime.now().isoformat()
        }
    
    def _char_to_viseme(self, char: str) -> Optional[Dict]:
        """Convert character to mock viseme data"""
        char_map = {
            'a': {"id": 1, "phoneme": "aa", "blendshapes": {"A": 0.8, "jawOpen": 0.3}},
            'e': {"id": 5, "phoneme": "eh", "blendshapes": {"E": 0.8, "jawOpen": 0.3}},
            'i': {"id": 3, "phoneme": "iy", "blendshapes": {"I": 0.9, "jawOpen": 0.1}},
            'o': {"id": 2, "phoneme": "ao", "blendshapes": {"O": 0.9, "jawOpen": 0.4}},
            'u': {"id": 4, "phoneme": "uw", "blendshapes": {"U": 0.9, "jawOpen": 0.2}},
            'b': {"id": 21, "phoneme": "b", "blendshapes": {"jawOpen": 0.1}},
            'p': {"id": 21, "phoneme": "p", "blendshapes": {"jawOpen": 0.1}},
            'm': {"id": 21, "phoneme": "m", "blendshapes": {"jawOpen": 0.1}},
            't': {"id": 18, "phoneme": "t", "blendshapes": {"I": 0.3, "jawOpen": 0.1}},
            'd': {"id": 21, "phoneme": "d", "blendshapes": {"I": 0.3, "jawOpen": 0.2}},
            'n': {"id": 18, "phoneme": "n", "blendshapes": {"I": 0.3, "jawOpen": 0.1}},
            'l': {"id": 15, "phoneme": "l", "blendshapes": {"I": 0.4, "jawOpen": 0.1}},
            'r': {"id": 16, "phoneme": "r", "blendshapes": {"U": 0.3, "jawOpen": 0.1}},
            's': {"id": 17, "phoneme": "s", "blendshapes": {"I": 0.5, "jawOpen": 0.05}},
            'f': {"id": 20, "phoneme": "f", "blendshapes": {"I": 0.4, "jawOpen": 0.05}},
            'h': {"id": 8, "phoneme": "ah", "blendshapes": {"A": 0.6, "jawOpen": 0.3}},
        }
        
        return char_map.get(char)
    
    async def get_available_voices(self) -> List[Dict]:
        """Get mock list of available voices"""
        return [
            {
                "name": "en-US-DavisNeural",
                "display_name": "Davis (Professional Male) - MOCK",
                "gender": "Male",
                "locale": "en-US",
                "description": "Mock voice for testing - confident, professional tone"
            },
            {
                "name": "en-US-AndrewNeural", 
                "display_name": "Andrew (Warm Male) - MOCK",
                "gender": "Male",
                "locale": "en-US",
                "description": "Mock voice for testing - warm, engaging tone"
            }
        ]
    
    def set_voice(self, voice_name: str):
        """Change the mock voice"""
        self.voice_name = voice_name
        print(f"🔧 Mock TTS voice set to: {voice_name}")

# Factory function to get the appropriate TTS service
def get_tts_service():
    """Get TTS service - real or mock depending on dependencies"""
    try:
        import azure.cognitiveservices.speech as speechsdk
        from tts_service import TTSService
        print("✅ Azure Speech SDK available, using real TTS service")
        return TTSService()
    except ImportError:
        print("⚠️ Azure Speech SDK not available, using mock TTS service")
        return MockTTSService()