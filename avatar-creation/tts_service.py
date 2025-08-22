"""
TTS Service with Viseme Support for 3D Avatar
Azure Speech Services integration with lip-sync data
"""

import azure.cognitiveservices.speech as speechsdk
import json
import asyncio
from typing import List, Dict, Optional
import os
import base64
from datetime import datetime

class VisemeMapping:
    """Maps Azure visemes to VRM blendshapes"""
    
    # Azure viseme to VRM A/I/U/E/O mapping
    VISEME_TO_VRM = {
        0: {"name": "sil", "blendshapes": {}},  # Silence
        1: {"name": "aa", "blendshapes": {"A": 0.8, "jawOpen": 0.3}},  # aa (father)
        2: {"name": "ao", "blendshapes": {"O": 0.9, "jawOpen": 0.4}},  # ao (ought)
        3: {"name": "iy", "blendshapes": {"I": 0.9, "jawOpen": 0.1}},  # iy (eat)
        4: {"name": "uw", "blendshapes": {"U": 0.9, "jawOpen": 0.2}},  # uw (boot)
        5: {"name": "eh", "blendshapes": {"E": 0.8, "jawOpen": 0.3}},  # eh (bet)
        6: {"name": "ih", "blendshapes": {"I": 0.7, "jawOpen": 0.2}},  # ih (bit)
        7: {"name": "uh", "blendshapes": {"U": 0.6, "jawOpen": 0.2}},  # uh (book)
        8: {"name": "ah", "blendshapes": {"A": 0.6, "jawOpen": 0.3}},  # ah (but)
        9: {"name": "ae", "blendshapes": {"A": 0.7, "E": 0.3, "jawOpen": 0.4}},  # ae (bat)
        10: {"name": "ey", "blendshapes": {"E": 0.8, "I": 0.2, "jawOpen": 0.2}},  # ey (bait)
        11: {"name": "ay", "blendshapes": {"A": 0.7, "I": 0.3, "jawOpen": 0.3}},  # ay (bite)
        12: {"name": "oy", "blendshapes": {"O": 0.7, "I": 0.3, "jawOpen": 0.3}},  # oy (boy)
        13: {"name": "aw", "blendshapes": {"A": 0.6, "U": 0.4, "jawOpen": 0.4}},  # aw (bout)
        14: {"name": "ow", "blendshapes": {"O": 0.8, "U": 0.2, "jawOpen": 0.3}},  # ow (boat)
        15: {"name": "l", "blendshapes": {"I": 0.4, "jawOpen": 0.1}},  # l (lid)
        16: {"name": "r", "blendshapes": {"U": 0.3, "jawOpen": 0.1}},  # r (red)
        17: {"name": "s", "blendshapes": {"I": 0.5, "jawOpen": 0.05}},  # s (sit)
        18: {"name": "t", "blendshapes": {"I": 0.3, "jawOpen": 0.1}},  # t (talk)
        19: {"name": "th", "blendshapes": {"I": 0.4, "jawOpen": 0.1}},  # th (think)
        20: {"name": "f", "blendshapes": {"I": 0.4, "jawOpen": 0.05}},  # f (fork)
        21: {"name": "dd", "blendshapes": {"I": 0.3, "jawOpen": 0.2}},  # dd (dad)
    }

class TTSService:
    """Azure Speech Services with viseme support"""
    
    def __init__(self):
        self.speech_key = os.getenv("AZURE_SPEECH_KEY")
        self.speech_region = os.getenv("AZURE_SPEECH_REGION", "eastus")
        self.voice_name = "en-US-DavisNeural"  # Professional male voice for Gojo
        
        if not self.speech_key:
            raise ValueError("AZURE_SPEECH_KEY environment variable not set")
        
        # Configure speech service
        self.speech_config = speechsdk.SpeechConfig(
            subscription=self.speech_key, 
            region=self.speech_region
        )
        self.speech_config.speech_synthesis_voice_name = self.voice_name
        self.speech_config.set_speech_synthesis_output_format(
            speechsdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoPcm
        )
        
        # For viseme events
        self.viseme_data = []
        self.audio_data = None
    
    def _on_viseme_received(self, evt):
        """Callback for viseme events from Azure Speech"""
        viseme_info = {
            "audio_offset": evt.audio_offset / 10000,  # Convert to milliseconds
            "viseme_id": evt.viseme_id,
            "blendshapes": VisemeMapping.VISEME_TO_VRM.get(evt.viseme_id, {}).get("blendshapes", {}),
            "phoneme": VisemeMapping.VISEME_TO_VRM.get(evt.viseme_id, {}).get("name", "unknown")
        }
        self.viseme_data.append(viseme_info)
    
    def _on_synthesis_completed(self, evt):
        """Callback when speech synthesis is complete"""
        if evt.result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            self.audio_data = evt.result.audio_data
        elif evt.result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = evt.result.cancellation_details
            print(f"Speech synthesis canceled: {cancellation_details.reason}")
    
    async def synthesize_with_visemes(self, text: str) -> Dict:
        """
        Synthesize speech with viseme data for 3D avatar lip-sync
        
        Returns:
        {
            "audio_base64": "base64 encoded audio data",
            "visemes": [{"audio_offset": ms, "viseme_id": int, "blendshapes": {...}}],
            "duration_ms": float,
            "sample_rate": 16000
        }
        """
        # Reset for new synthesis
        self.viseme_data = []
        self.audio_data = None
        
        # Create synthesizer
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=self.speech_config,
            audio_config=None  # No audio output, we'll get data from callback
        )
        
        # Connect event handlers
        synthesizer.viseme_received.connect(self._on_viseme_received)
        synthesizer.synthesis_completed.connect(self._on_synthesis_completed)
        
        # Create SSML for better control
        ssml = f"""
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
            <voice name="{self.voice_name}">
                <prosody rate="0.9" pitch="+2st" volume="85">
                    {text}
                </prosody>
            </voice>
        </speak>
        """
        
        # Run synthesis in executor to avoid blocking
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None, 
            lambda: synthesizer.speak_ssml(ssml)
        )
        
        if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
            raise Exception(f"Speech synthesis failed: {result.reason}")
        
        # Calculate duration
        duration_ms = len(self.audio_data) / (16000 * 2) * 1000  # 16kHz, 16-bit
        
        return {
            "audio_base64": base64.b64encode(self.audio_data).decode('utf-8'),
            "visemes": sorted(self.viseme_data, key=lambda x: x["audio_offset"]),
            "duration_ms": duration_ms,
            "sample_rate": 16000,
            "voice": self.voice_name,
            "timestamp": datetime.now().isoformat()
        }
    
    async def get_available_voices(self) -> List[Dict]:
        """Get list of available voices for Gojo character"""
        # For now, return our curated professional male voices
        return [
            {
                "name": "en-US-DavisNeural",
                "display_name": "Davis (Professional Male)",
                "gender": "Male",
                "locale": "en-US",
                "description": "Confident, professional tone - ideal for Gojo"
            },
            {
                "name": "en-US-AndrewNeural", 
                "display_name": "Andrew (Warm Male)",
                "gender": "Male",
                "locale": "en-US",
                "description": "Warm, engaging tone"
            },
            {
                "name": "en-US-BrianNeural",
                "display_name": "Brian (Authoritative Male)",
                "gender": "Male", 
                "locale": "en-US",
                "description": "Clear, authoritative tone"
            }
        ]
    
    def set_voice(self, voice_name: str):
        """Change the voice for Gojo"""
        self.voice_name = voice_name
        self.speech_config.speech_synthesis_voice_name = voice_name