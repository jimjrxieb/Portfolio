# Gojo Satoru VRM Avatar Setup

## 🎭 Getting a Gojo VRM Model

### Free Options:
1. **VRoid Hub** - Search "Gojo Satoru"
   - https://hub.vroid.com/
   - Look for models with commercial use allowed

2. **Booth.pm** - Japanese marketplace
   - https://booth.pm/en/search/五条悟
   - Filter by "Free" and "VRM"

3. **Sketchfab** - 3D model platform
   - Search "Gojo Satoru VRM"
   - Download and convert FBX/GLTF to VRM if needed

### Recommended Model Specs:
- **Format**: .vrm (preferred) or .glb
- **Polycount**: Under 50k for web performance
- **Blendshapes Required**:
  - Vowels: A, I, U, E, O (あいうえお)
  - Mouth: jaw_open, mouth_smile
  - Eyes: blink, blink_L, blink_R
- **Textures**: 2K max resolution

## 📥 Installation Steps

1. **Download a Gojo VRM model** from one of the sources above
2. **Rename the file** to `gojo.vrm`
3. **Place it in this directory** (`/ui/public/avatars/`)
4. The avatar will automatically load when you refresh the page

## 🎨 Model Requirements

The model should have:
- **White/silver spiky hair** (Gojo's signature)
- **Blue eyes** (preferably with glow/emission)
- **Black high-collar outfit** or similar
- **Proper rigging** for head/neck movement
- **Face blendshapes** for expressions

## ⚙️ Converting Other Formats to VRM

If you find a good Gojo model in FBX/PMX format:

1. **Use UniVRM** (Unity plugin):
   ```
   - Import model into Unity
   - Add UniVRM package
   - Configure blendshapes
   - Export as VRM
   ```

2. **Use VRoid Studio** (for editing):
   ```
   - Import base model
   - Customize hair/eyes/outfit
   - Export as VRM
   ```

## 🔧 Fallback Avatar

If no `gojo.vrm` file is found, the system will use the built-in geometric fallback avatar with:
- White spiky hair spheres
- Blue glowing eyes
- Basic face structure
- Dark body cylinder

## 📝 License Notes

- Always check the model's license before use
- For portfolio/non-commercial: Most fan models are OK
- For commercial use: Look for CC0 or commercial-allowed licenses
- Credit the original creator when possible

## 🚀 Performance Tips

- Keep file size under 10MB for fast loading
- Use compressed textures (JPEG for diffuse, PNG for transparency)
- Reduce polygon count if model is too detailed
- Test on mobile devices for performance

---

Once you add a `gojo.vrm` file here, the avatar will automatically upgrade from the fallback to the full 3D model!