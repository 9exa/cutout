# Cutout Plugin for Godot 4.6+

A Godot plugin that creates extruded 3D meshes from 2D textures using advanced contour extraction algorithms. Perfect for creating cardboard cutout effects, sprite extrusion, and dynamic destruction systems.

![Plugin Version](https://img.shields.io/badge/version-1.0.0-blue)
![Godot Version](https://img.shields.io/badge/godot-4.6+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

- **🎨 Automatic Contour Extraction** - Multiple algorithms (Marching Squares, Moore Neighbour)
- **📐 Polygon Simplification** - RDP, Visvalingam-Whyatt, and Reumann-Witkam algorithms
- **✨ Smoothing Options** - Outward expansion for cleaner meshes
- **🔧 Editor Integration** - Full-featured dock with live 2D/3D preview
- **💥 Destruction System** - Voronoi and slice-based dynamic mesh splitting
- **🎭 Material Support** - Custom shaders, backgrounds, and per-instance overrides
- **⚡ Performance** - Native Rust GDExtension for heavy computation (contour, simplify, fracture)

## 📦 Installation

### Manual Installation

#### Requirements

Parts of this addon are written in Rust. To build the native extension, you need the [Rust toolchain](https://www.rust-lang.org/tools/install) and [Cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html).

1. Clone or download this repository
2. Copy the `addons/cutout/` folder into your project's `addons/` directory
3. Build the GDExtension by navigating to `addons/cutout/cutout-gdext/` and running:
   ```bash
   cargo build --release
   # Then copy the built library (see copy_lib.sh / copy_lib.ps1)
   ```
4. Enable the plugin in **Project Settings → Plugins → Cutout**

## 🚀 Quick Start

### Basic Usage

1. **Enable the Plugin**
   - Project → Project Settings → Plugins → Enable "Cutout"

2. **Open the Cutout Dock**
   - The "Cutout" dock appears at the bottom of the editor

3. **Create a Cutout Mesh**
   - Click "Select Image" and choose a PNG with transparency
   - Adjust algorithm settings in real-time
   - Preview in 2D or 3D tabs
   - Click "Export" to save as a `.tres` resource

4. **Use in Your Scene**

   ```gdscript
   # Add a CutoutMeshInstance3D node to your scene
   var cutout = CutoutMeshInstance3D.new()
   cutout.cutout_mesh = preload("res://my_cutout.tres")
   add_child(cutout)
   ```

### Programmatic Creation

```gdscript
# Create mesh resource
var cutout_mesh = CutoutMesh.new()
cutout_mesh.texture = preload("res://character.png")

# Configure contour extraction
var contour = CutoutContourMarchingSquares.new()
contour.alpha_threshold = 0.5
var polygons = contour.calculate_boundary(cutout_mesh.texture.get_image())

# Set mask and generate
cutout_mesh.mask = polygons
cutout_mesh.depth = 0.1
cutout_mesh.mesh_size = Vector2(1.0, 1.5)

# Use in scene
var instance = CutoutMeshInstance3D.new()
instance.cutout_mesh = cutout_mesh
add_child(instance)
```

## 🎮 Examples & Demos

Demo scenes and examples are located in `addons/cutout/demo_project/`:

- **`demo_project/examples/animated_shaders/`** - Custom background and extrusion shader examples
- **`demo_project/examples/destruction/`** - Interactive destruction showcase with physics
- **`demo_project/tests/`** - Visualizer scenes for contour, polygon, destruction testing

Sample assets (e.g. `siobhan.png`, `papier-textur-hintergrund-karton.jpg`) are also stored in `demo_project/`.

## 🏗️ Project Structure

```
cardboard-demo/                        # Godot project root
├── addons/cutout/                     # The plugin (distributable)
│   ├── plugin.cfg                     # Plugin metadata
│   ├── cutout_plugin.gd               # Plugin entry point (@tool)
│   ├── cutout.gdextension             # GDExtension descriptor
│   │
│   ├── cutout-gdext/                  # Rust GDExtension source
│   │   ├── Cargo.toml
│   │   ├── src/
│   │   │   ├── lib.rs                 # Extension entry point
│   │   │   ├── contour/              # Contour extraction (Marching Squares, Moore Neighbour)
│   │   │   ├── simplify/             # Polygon simplification (RDP, VW, RW)
│   │   │   ├── fracture/             # Mesh fracture (Voronoi, slices)
│   │   │   └── common/               # Shared math/geometry utilities
│   │   ├── build.sh / build.ps1       # Build scripts
│   │   └── copy_lib.sh / copy_lib.ps1 # Copy compiled DLL into addon
│   │
│   ├── nodes/
│   │   └── cutout_mesh_instance_3d.gd # CutoutMeshInstance3D node
│   │
│   ├── resources/
│   │   ├── cutout_mesh.gd             # CutoutMesh resource
│   │   ├── contour/                   # Contour algorithm resources
│   │   │   ├── cutout_contour_algorithm.gd       # Base class
│   │   │   ├── cutout_contour_data.gd
│   │   │   ├── cutout_contour_marching_squares.gd
│   │   │   └── cutout_contour_moore_neighbour.gd
│   │   ├── polysimp/                  # Polygon simplification resources
│   │   │   ├── cutout_polysimp.gd                # Base class
│   │   │   ├── cutout_polysimp_rdp.gd            # Ramer-Douglas-Peucker
│   │   │   ├── cutout_polysimp_vw.gd             # Visvalingam-Whyatt
│   │   │   └── cutout_polysimp_rw.gd             # Reumann-Witkam
│   │   ├── smooth/                    # Smoothing resources
│   │   │   ├── cutout_smooth.gd                  # Base class
│   │   │   └── cutout_smooth_outward.gd          # Outward expansion
│   │   └── destruction/               # Destruction resources
│   │       ├── cutout_destruction.gd             # Base class
│   │       ├── cutout_destruction_voronoi.gd     # Voronoi fracture
│   │       └── cutout_destruction_slices.gd      # Slice-based fracture
│   │
│   ├── ui/                            # Editor dock UI
│   │   ├── cutout_dock.tscn / .gd     # Main editor dock
│   │   ├── mesh_preview_3d.gd         # 3D viewport preview
│   │   ├── polygon_preview.gd         # 2D polygon preview
│   │   ├── orbit_camera_3d.gd         # Orbit camera for 3D preview
│   │   └── pan_zoom_camera_2d.gd      # Pan/zoom camera for 2D preview
│   │
│   ├── shaders/                       # Built-in shaders
│   │   ├── cutout_background_composite.gdshader
│   │   └── cutout_background_composite.tres
│   │
│   ├── utils/                         # GDScript utilities
│   │   ├── cutout_algorithm_registry.gd  # Auto-discovers algorithm resources
│   │   ├── cutout_geometry_utils.gd
│   │   └── image_utils.gd
│   │
│   └── demo_project/                  # Demo scenes and test assets
│       ├── siobhan.png                # Sample character sprite
│       ├── papier-textur-hintergrund-karton.jpg  # Sample cardboard texture
│       ├── siobhan_cutout.tres        # Pre-built example CutoutMesh
│       ├── examples/
│       │   ├── animated_shaders/      # Shader animation examples
│       │   └── destruction/           # Destruction system demo
│       └── tests/                     # Visualizer and unit test scenes
│
├── export_plugin.sh                   # Asset Library export script
├── project.godot                      # Godot project file
├── TODO_FEATURES.md                   # Planned features
└── README.md                          # This file
```

## 🔧 Development

### Building the Rust Extension

```bash
cd addons/cutout/cutout-gdext
cargo build --release
./copy_lib.sh        # or copy_lib.ps1 on Windows
```

### Exporting for Asset Library

```bash
# Creates a clean ZIP with only plugin files
./export_plugin.sh 1.0.0
```

### Adding New Algorithms

1. Create a new script in the appropriate subdirectory under `addons/cutout/resources/`
2. Extend the relevant base class (`CutoutContourAlgorithm`, `CutoutPolysimp`, `CutoutSmooth`, or `CutoutDestruction`)
3. Add a `class_name` declaration
4. The plugin auto-discovers it via `CutoutAlgorithmRegistry`

Example:

```gdscript
@tool
class_name CutoutContourMyAlgorithm
extends CutoutContourAlgorithm

const DISPLAY_NAME := "My Algorithm"

@export_range(0.0, 1.0) var my_parameter: float = 0.5

func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
    # Your implementation here
    return []
```

## 📄 License

MIT License - See [LICENSE](LICENSE) for details
