# Cutout Shaders

This directory contains shader materials for advanced rendering effects with CutoutMesh.

## Background Composite Shader

**Files:**
- `cutout_background_composite.gdshader` - The shader code
- `cutout_background_composite.tres` - Pre-configured ShaderMaterial template

### Purpose

Shows a background material behind the main texture where:
- The main texture's alpha channel is 0 (transparent areas)
- The main texture is null/missing

This is useful for:
- Creating layered sprite effects
- Showing different materials through transparent cutouts
- Providing fallback visuals when textures are missing

### How to Use

1. **Duplicate the template material**
   - In Godot, navigate to `res://addons/cutout/shaders/cutout_background_composite.tres`
   - Right-click and select "Duplicate"
   - Save it to your project directory

2. **Configure the shader parameters**
   - `foreground_texture`: Your main sprite/cutout texture
   - `background_color`: Solid color to show behind transparent areas (default: white)
   - `use_background_texture`: Enable this to use a texture instead of solid color
   - `background_texture`: The background texture (only used if `use_background_texture` is true)
   - `alpha_scissor`: Optional hard cutoff threshold (0.0 = disabled)

3. **Apply to your CutoutMeshInstance3D**
   - Select your CutoutMeshInstance3D node
   - In the Inspector, find the `Override Face Material` property
   - Assign your duplicated shader material

### Example Configurations

**Solid Color Background:**
```
foreground_texture = preload("res://my_sprite.png")
background_color = Color(0.2, 0.5, 0.8, 1.0)  # Blue background
use_background_texture = false
```

**Textured Background:**
```
foreground_texture = preload("res://my_sprite.png")
background_texture = preload("res://wood_texture.png")
use_background_texture = true
```

**Alpha Scissor (Hard Cutoff):**
```
foreground_texture = preload("res://my_sprite.png")
background_color = Color(1, 1, 1, 1)
alpha_scissor = 0.5  # Discard pixels with alpha < 0.5
```

### Technical Details

The shader uses alpha blending to composite the foreground and background:
```glsl
vec4 final_color = mix(background, foreground, foreground.a);
```

- When `foreground.a = 0`: 100% background is shown
- When `foreground.a = 1`: 100% foreground is shown
- When `foreground.a = 0.5`: 50% blend of both

The face surface uses standard UV mapping (0-1 range), so both foreground and background textures are sampled with the same coordinates.

### Notes

- The default face material does NOT have transparency enabled (for performance reasons)
- This shader handles its own transparency via `render_mode blend_mix`
- The shader works on both front and back faces (Surface 0)
- For different materials on front vs back, you would need to split the mesh into separate surfaces
- If you need transparency with StandardMaterial3D, manually set `transparency = TRANSPARENCY_ALPHA`
