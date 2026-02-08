# Cutout Plugin for Godot 4.6+

A powerful Godot plugin that creates extruded 3D meshes from 2D textures using advanced contour extraction algorithms. Perfect for creating cardboard cutout effects, sprite extrusion, and dynamic destruction systems.

![Plugin Version](https://img.shields.io/badge/version-1.0.0-blue)
![Godot Version](https://img.shields.io/badge/godot-4.6+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

- **🎨 Automatic Contour Extraction** - Multiple algorithms (Marching Squares, Moore Neighbor)
- **📐 Polygon Simplification** - RDP, Visvalingam-Whyatt, and Reumann-Witkam algorithms
- **✨ Smoothing Options** - Outward expansion for cleaner meshes
- **🔧 Editor Integration** - Full-featured dock with live 2D/3D preview
- **💥 Destruction System** - Voronoi and slice-based dynamic mesh splitting
- **🎭 Material Support** - Custom shaders, backgrounds, and per-instance overrides
- **⚡ Performance** - Cached resources, incremental pipeline, optimized geometry

## 📦 Installation

### From Godot Asset Library
1. Open Godot Editor → AssetLib
2. Search for "Cutout"
3. Download and install
4. Enable plugin in Project Settings → Plugins

### Manual Installation
1. Download the latest release from [GitHub Releases](https://github.com/yourusername/cutout_plugin/releases)
2. Extract to your project's `addons/` folder
3. Enable plugin in Project Settings → Plugins

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
   - Click "Export" to save as `.tres` resource

4. **Use in Your Scene**
   ```gdscript
   # Add a CutoutMeshInstance3D node
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

Examples and demo scenes are available in the [demo_project/](demo_project/) folder:

- **Basic Usage** - Simple cutout mesh creation
- **Animated Shaders** - Custom background and extrusion materials
- **Destruction System** - Interactive destruction with physics

## 📚 Documentation

- **[API Documentation](docs/API.md)** - Full API reference
- **[Dock Guide](docs/DOCK_TESTING_GUIDE.md)** - Editor dock usage
- **[Algorithm Guide](docs/ALGORITHMS.md)** - Choosing the right algorithms

## 🏗️ Project Structure

```
cutout_plugin/
├── addons/cutout/          # Plugin files (for distribution)
│   ├── nodes/              # CutoutMeshInstance3D node
│   ├── resources/          # CutoutMesh and algorithm resources
│   ├── ui/                 # Editor dock and previews
│   ├── utils/              # Geometry utilities and registry
│   └── plugin.cfg          # Plugin configuration
│
├── demo_project/           # Examples and tests (NOT in distribution)
│   ├── examples/           # Usage examples
│   ├── tests/              # Unit tests
│   └── assets/             # Test images and resources
│
├── docs/                   # Documentation (NOT in distribution)
├── export_plugin.sh        # Asset Library export script
├── README.md               # This file
└── LICENSE                 # MIT License
```

## 🔧 Development

### Running Tests
```bash
# Unit tests are in demo_project/tests/
# Open test scenes in Godot editor to run
```

### Exporting for Asset Library
```bash
# Creates a clean ZIP with only plugin files
./export_plugin.sh 1.0.0
# Output: asset_library_export/godot-cutout-plugin-1.0.0.zip
```

### Adding New Algorithms

1. Create a new script in `addons/cutout/resources/[contour|polysimp|smooth]/`
2. Extend the appropriate base class (`CutoutContourAlgorithm`, etc.)
3. Add `class_name` declaration
4. The plugin will auto-discover it via `CutoutAlgorithmRegistry`

Example:
```gdscript
@tool
class_name CutoutContourMyAlgorithm
extends CutoutContourAlgorithm

const DISPLAY_NAME := "My Algorithm"

@export_range(0.0, 1.0) var my_parameter: float = 0.5

func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
    # Your implementation
    return []
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

## 🙏 Credits

Created by [Your Name]

### Special Thanks
- Godot Engine community
- Algorithm implementations based on academic papers (see code comments)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/cutout_plugin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/cutout_plugin/discussions)
- **Discord**: [Your Discord Server]

## 🗺️ Roadmap

- [ ] Multi-polygon support (holes)
- [ ] Bezier curve smoothing
- [ ] Normal map generation for depth
- [ ] Animation support
- [ ] C# bindings

---

**Made with ❤️ for the Godot community**
