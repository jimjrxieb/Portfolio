# Creating Gojo Satoru VRM Model - Step by Step

## 🎨 Method 1: VRoid Studio (Free, 30 minutes)

### 1. Download VRoid Studio
- **Download**: https://vroid.com/en/studio
- Free, works on Windows/Mac
- No modeling experience needed

### 2. Create Gojo Base

#### Hair (Most Important):
1. **Hair Color**: 
   - Base: Pure White (#FFFFFF)
   - Shadow: Light Blue (#E6F3FF)
   - Highlight: Bright White (#FFFFFF)

2. **Hair Style**:
   - Use "Short Hair" preset
   - Add procedural hair groups:
     - Front: Spiky bangs swept up
     - Top: Multiple spike groups pointing up/back
     - Sides: Shorter, swept back
   - Make it messy/spiky using the hair tools

#### Eyes (Six Eyes):
1. **Eye Color**:
   - Iris: Bright Cyan (#00D4FF)
   - Add "Star" or "Sparkle" highlight
   - Pupil: Small, sharp

2. **Eye Shape**:
   - Narrow, confident look
   - Slightly upturned outer corners

#### Face:
1. **Skin Tone**: Light/Fair
2. **Face Shape**: Sharp jawline
3. **Expression**: Confident smirk preset

#### Outfit:
1. **Top**: 
   - Use "Uniform" or "Jacket" preset
   - Color: Black (#1A1A1A)
   - High collar if available

### 3. Export Settings
1. Go to **Export** → **Export as VRM**
2. Settings:
   - **Title**: "Gojo Satoru"
   - **Version**: "1.0"
   - **Author**: Your name
   - **License**: "Other" (for personal use)
3. **Reduce Polygons**: Set to "VRM0.0" and "Low" quality for web
4. **Export Blendshapes**: Make sure these are checked:
   - A, I, U, E, O (vowels)
   - Blink, Blink_L, Blink_R
   - Joy, Angry, Sorrow, Fun

---

## 🤖 Method 2: Ready-Made Base + Customization

### Quick Setup with Existing Model:

1. **Get Base Anime Male Model**:
   ```bash
   # Download a free base model (CC0 license)
   wget https://github.com/vrm-c/UniVRM/raw/master/Tests/Models/Alicia_vrm-0.51.vrm -O base_model.vrm
   ```

2. **Use VRM Editor Online**:
   - Go to: https://www.vrmposing.com/
   - Upload base model
   - Modify textures:
     - Hair → White
     - Eyes → Cyan
     - Outfit → Black

3. **Save as gojo.vrm**

---

## 💻 Method 3: Programmatic Avatar (Three.js)

Since you don't have a VRM file, let's create a much better programmatic Gojo that actually looks good:

```javascript
// Better Gojo Avatar Creation
class GojoAvatarBuilder {
  static createGojo(scene) {
    const gojo = new THREE.Group();
    
    // Head with proper anime proportions
    const headGeometry = new THREE.BoxGeometry(0.45, 0.55, 0.4);
    headGeometry.translate(0, 0, 0.05);
    const skinMaterial = new THREE.MeshToonMaterial({ 
      color: 0xFFDBB4,
      gradientMap: this.createToonGradient()
    });
    const head = new THREE.Mesh(headGeometry, skinMaterial);
    head.position.y = 1.6;
    
    // Anime-style hair (multiple spikes)
    const hairSpikes = [];
    const spikePositions = [
      { x: 0, y: 1.9, z: 0, scale: [0.4, 0.3, 0.3], rotation: [0, 0, 0] },
      { x: -0.15, y: 1.85, z: 0.1, scale: [0.2, 0.25, 0.2], rotation: [0, 0, -0.3] },
      { x: 0.15, y: 1.85, z: 0.1, scale: [0.2, 0.25, 0.2], rotation: [0, 0, 0.3] },
      { x: 0, y: 1.95, z: -0.1, scale: [0.3, 0.2, 0.2], rotation: [-0.2, 0, 0] },
      { x: -0.1, y: 1.92, z: -0.15, scale: [0.15, 0.2, 0.15], rotation: [-0.3, -0.2, -0.2] },
      { x: 0.1, y: 1.92, z: -0.15, scale: [0.15, 0.2, 0.15], rotation: [-0.3, 0.2, 0.2] },
    ];
    
    const hairMaterial = new THREE.MeshToonMaterial({ 
      color: 0xF8F8FF,
      gradientMap: this.createToonGradient()
    });
    
    spikePositions.forEach(pos => {
      const spike = new THREE.Mesh(
        new THREE.ConeGeometry(pos.scale[0], pos.scale[1], 4),
        hairMaterial
      );
      spike.position.set(pos.x, pos.y, pos.z);
      spike.rotation.set(...pos.rotation);
      gojo.add(spike);
    });
    
    // Glowing Six Eyes
    const eyeGeometry = new THREE.SphereGeometry(0.06, 16, 16);
    const eyeMaterial = new THREE.MeshBasicMaterial({ 
      color: 0x00D4FF,
      emissive: 0x00D4FF,
      emissiveIntensity: 2
    });
    
    const leftEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
    leftEye.position.set(-0.1, 1.6, 0.2);
    leftEye.scale.set(1, 0.7, 1); // Anime eye shape
    
    const rightEye = leftEye.clone();
    rightEye.position.set(0.1, 1.6, 0.2);
    
    // Eye glow effect
    const glowMaterial = new THREE.SpriteMaterial({
      map: this.createGlowTexture(),
      color: 0x00D4FF,
      blending: THREE.AdditiveBlending,
      opacity: 0.5
    });
    
    const leftGlow = new THREE.Sprite(glowMaterial);
    leftGlow.position.copy(leftEye.position);
    leftGlow.scale.set(0.3, 0.3, 1);
    
    const rightGlow = leftGlow.clone();
    rightGlow.position.copy(rightEye.position);
    
    // High collar uniform
    const bodyGeometry = new THREE.CylinderGeometry(0.35, 0.4, 1.2, 8);
    const uniformMaterial = new THREE.MeshToonMaterial({ 
      color: 0x1A1A1A
    });
    const body = new THREE.Mesh(bodyGeometry, uniformMaterial);
    body.position.y = 0.7;
    
    // Collar detail
    const collarGeometry = new THREE.CylinderGeometry(0.2, 0.25, 0.2, 8);
    const collar = new THREE.Mesh(collarGeometry, uniformMaterial);
    collar.position.y = 1.35;
    
    // Assemble
    gojo.add(head, leftEye, rightEye, leftGlow, rightGlow, body, collar);
    
    // Store references for animation
    gojo.userData = {
      leftEye,
      rightEye,
      head,
      hairSpikes
    };
    
    return gojo;
  }
  
  static createToonGradient() {
    const colors = new Uint8Array(3);
    colors[0] = 64;
    colors[1] = 128;
    colors[2] = 255;
    const gradientMap = new THREE.DataTexture(colors, colors.length, 1, THREE.LuminanceFormat);
    gradientMap.needsUpdate = true;
    return gradientMap;
  }
  
  static createGlowTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d');
    
    const gradient = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    gradient.addColorStop(0, 'rgba(0, 212, 255, 1)');
    gradient.addColorStop(0.5, 'rgba(0, 212, 255, 0.5)');
    gradient.addColorStop(1, 'rgba(0, 212, 255, 0)');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 64, 64);
    
    return new THREE.CanvasTexture(canvas);
  }
}
```

---

## 🎯 Fastest Solution: Download & Modify

### Pre-made Gojo Models (Free):

1. **VRChat Avatar World**:
   - Join VRChat (free)
   - Search worlds: "Gojo Avatar"
   - Export using Unity

2. **MMD Models** (Convert to VRM):
   - Search: "Gojo Satoru MMD model"
   - Download PMX file
   - Convert using VRoid Studio or Blender

3. **Sketchfab** (Direct download):
   - https://sketchfab.com/search?q=gojo+satoru&type=models
   - Filter: "Downloadable" + "Free"
   - Convert to VRM using Unity

---

## 📦 File Placement

Once you have your `gojo.vrm`:

```bash
# Place the file here:
/home/jimmie/linkops-industries/Portfolio/ui/public/avatars/gojo.vrm

# The app will automatically detect and load it
```

---

## 🚀 Recommended: Quick VRoid Studio

This is the fastest way to get a working Gojo:
1. Takes 30 minutes
2. Free software
3. Exports directly to VRM
4. Has all needed blendshapes
5. Web-optimized output

Would you like me to create the enhanced programmatic version instead while you work on the VRM?