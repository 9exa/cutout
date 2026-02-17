# Polygon Destruction Showcase

## Overview

This showcase demonstrates the polygon destruction capabilities of the CutoutMesh system in a fully interactive 3D environment. Players can walk around in first-person view and trigger realistic polygon-based destruction on CutoutMeshInstance3D objects, with physics simulation and explosion effects.

## Features

- **First-Person Controller**: Full FPS-style movement with mouse look, WASD controls, sprint, and jump
- **Interactive Destruction**: Look at destructible objects and press 'E' to trigger destruction
- **Physics-Based Fragments**: Destroyed pieces become RigidBody3D objects with realistic physics
- **Multiple Destruction Patterns**: Cycle through different Voronoi patterns (Random, Grid, Radial, Spiderweb, Poisson Disk)
- **Explosion Effects**: Sound effects and explosion forces applied to fragments
- **Reset System**: Press 'R' to respawn destructible objects for repeated testing
- **Debug UI**: Shows interaction prompts, current destruction pattern, and performance metrics

## File Structure

All files are located in `examples/destruction/`:

```
examples/destruction/
├── DESTRUCTION_EXAMPLE.md         # This documentation
├── destruction_showcase.tscn      # Main scene file
├── player.tscn                   # Player character prefab
├── destructible_cutout.tscn      # Destructible object prefab
├── player_controller.gd          # First-person movement controller
├── interaction_system.gd         # Raycast interaction system
├── destructible_cutout.gd        # Main destruction logic
├── cutout_fragment.gd            # Physics fragment behavior
├── destruction_showcase_main.gd  # Scene controller
├── explosion.ogg                 # Explosion sound effect
└── target_texture.png            # Texture for destructible mesh
```

## Implementation Details

### 1. Player Controller (`player_controller.gd`)

Handles first-person character movement and camera control.

**Key Properties:**
- `movement_speed: float = 5.0` - Base walking speed
- `sprint_speed: float = 8.0` - Speed when holding Shift
- `jump_velocity: float = 8.0` - Jump force
- `mouse_sensitivity: float = 0.002` - Camera rotation sensitivity
- `gravity: float = 20.0` - Gravity force

**Key Methods:**
```gdscript
func _ready():
    # Capture mouse for FPS controls
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
    # Handle mouse look
    if event is InputEventMouseMotion:
        rotate_camera(event.relative)

func _physics_process(delta):
    # Handle WASD movement, jumping, and gravity
    process_movement(delta)
```

### 2. Interaction System (`interaction_system.gd`)

Manages raycast-based object interaction from the player's camera.

**Key Properties:**
- `interaction_range: float = 5.0` - Maximum interaction distance
- `interact_key: String = "e"` - Key to trigger interaction

**Key Methods:**
```gdscript
func check_interaction() -> void:
    # Cast ray from camera center
    var ray_result = cast_interaction_ray()

    if ray_result and ray_result.collider.has_method("can_interact"):
        show_interaction_prompt()

        if Input.is_action_just_pressed(interact_key):
            ray_result.collider.interact()

func cast_interaction_ray() -> Dictionary:
    # Performs raycast from camera center
    var camera = get_viewport().get_camera_3d()
    var from = camera.global_position
    var to = from + -camera.global_transform.basis.z * interaction_range
    return space_state.intersect_ray(from, to)
```

### 3. Destructible Cutout (`destructible_cutout.gd`)

Core destruction logic that manages CutoutMeshInstance3D destruction.

**Key Properties:**
- `fragment_count: int = 15` - Number of destruction fragments
- `destruction_pattern: CutoutDestructionVoronoi.SeedPattern` - Current pattern
- `explosion_force: float = 10.0` - Force applied to fragments
- `fragment_lifetime: float = 10.0` - Time before fragments disappear

**Key Methods:**
```gdscript
func destruct() -> void:
    # Get the CutoutMesh from the instance
    var cutout_mesh = $CutoutMeshInstance3D.cutout_mesh

    # Create destruction algorithm
    var destruction = CutoutDestructionVoronoi.new()
    destruction.fragment_count = 15  # Voronoi-specific property
    destruction.pattern = destruction_pattern
    destruction.seed = randi()

    # Fracture the polygon mask
    var fragments = destruction.fracture(cutout_mesh.mask)

    # Create physics fragments for each piece
    for fragment_polygon in fragments:
        spawn_fragment(fragment_polygon, cutout_mesh)

    # Play explosion sound and hide original
    $AudioStreamPlayer3D.play()
    $CutoutMeshInstance3D.visible = false

func spawn_fragment(polygon: PackedVector2Array, original_mesh: CutoutMesh) -> void:
    # Create fragment CutoutMesh
    var fragment_mesh = CutoutMesh.new()
    fragment_mesh.texture = original_mesh.texture
    fragment_mesh.mask = [polygon]
    fragment_mesh.depth = original_mesh.depth
    fragment_mesh.mesh_size = original_mesh.mesh_size

    # Create RigidBody3D with CutoutMeshInstance3D
    var fragment = preload("res://examples/destruction/cutout_fragment.gd").new()
    fragment.setup(fragment_mesh, explosion_force, fragment_lifetime)
    get_parent().add_child(fragment)
```

### 4. Cutout Fragment (`cutout_fragment.gd`)

Individual fragment behavior as a physics object.

**Key Properties:**
- `cutout_mesh_instance: CutoutMeshInstance3D` - Visual representation
- `lifetime: float` - Time before deletion
- `fade_time: float = 2.0` - Fade-out duration

**Key Methods:**
```gdscript
func setup(cutout_mesh: CutoutMesh, explosion_force: float, lifetime: float) -> void:
    # Create visual mesh
    cutout_mesh_instance = CutoutMeshInstance3D.new()
    cutout_mesh_instance.cutout_mesh = cutout_mesh
    add_child(cutout_mesh_instance)

    # Generate collision shape from mesh
    var collision_shape = create_trimesh_collision()
    add_child(collision_shape)

    # Apply explosion impulse
    var direction = (global_position - get_parent().global_position).normalized()
    apply_central_impulse(direction * explosion_force)
    apply_torque_impulse(Vector3(randf(), randf(), randf()) * explosion_force * 0.5)

    # Start lifetime timer
    await get_tree().create_timer(lifetime - fade_time).timeout
    start_fade_out()
```

### 5. Scene Controller (`destruction_showcase_main.gd`)

Main scene management and UI control.

**Key Properties:**
- `destructible_scene: PackedScene` - Destructible object prefab
- `spawn_position: Vector3` - Where to spawn destructibles
- `ui_labels: Dictionary` - UI element references

**Key Methods:**
```gdscript
func _ready():
    # Initialize UI
    setup_ui()

    # Spawn initial destructible
    spawn_destructible()

func _input(event):
    if Input.is_action_just_pressed("reset"):  # 'R' key
        reset_scene()

    if Input.is_action_just_pressed("cycle_pattern"):  # Tab key
        cycle_destruction_pattern()

func reset_scene():
    # Remove existing destructible and fragments
    cleanup_scene()

    # Spawn new destructible
    spawn_destructible()
```

## Scene Setup

### Main Scene (`destruction_showcase.tscn`)

```
Node3D (Root)
├── Environment
│   ├── DirectionalLight3D (Sun)
│   └── WorldEnvironment (Sky and fog)
├── Ground
│   ├── StaticBody3D
│   ├── MeshInstance3D (Large plane)
│   └── CollisionShape3D (Box)
├── Player (Instance of player.tscn)
├── DestructibleContainer
│   └── DestructibleCutout (Instance of destructible_cutout.tscn)
└── UI
    ├── CanvasLayer
    ├── Crosshair (TextureRect or Label with "+")
    ├── InteractionPrompt (Label)
    └── DebugInfo (Label for FPS, pattern info)
```

### Player Prefab (`player.tscn`)

```
CharacterBody3D (Root) [player_controller.gd]
├── CollisionShape3D (Capsule)
├── Head (Node3D for rotation pivot)
│   └── Camera3D [interaction_system.gd]
└── AudioListener3D
```

### Destructible Prefab (`destructible_cutout.tscn`)

```
Node3D (Root) [destructible_cutout.gd]
├── CutoutMeshInstance3D (The visible mesh)
├── StaticBody3D (For interaction detection)
│   └── CollisionShape3D
├── AudioStreamPlayer3D (Explosion sound)
└── GPUParticles3D (Optional debris effect)
```

## Usage Instructions

### Running the Showcase

1. Open the project in Godot
2. Navigate to `examples/destruction/destruction_showcase.tscn`
3. Press F6 or click "Play Scene" to run

### Controls

- **WASD** - Move around
- **Mouse** - Look around
- **Space** - Jump
- **Shift** - Sprint
- **E** - Destroy object (when prompted)
- **R** - Reset the scene
- **Tab** - Cycle destruction patterns
- **Escape** - Release mouse cursor

### Interaction

1. Walk up to the destructible CutoutMeshInstance3D
2. Look directly at it (crosshair on target)
3. When you see "Press E to Destroy" prompt, press E
4. Watch the object shatter into physics fragments
5. Press R to reset and try different patterns

## Customization Guide

### Changing Destruction Parameters

Edit `destructible_cutout.gd`:

```gdscript
@export var fragment_count: int = 15  # More fragments = smaller pieces
@export var explosion_force: float = 10.0  # Higher = more violent explosion
@export var fragment_lifetime: float = 10.0  # Seconds before fragments disappear
@export var destruction_pattern = CutoutDestructionVoronoi.SeedPattern.RANDOM
```

### Available Destruction Patterns

1. **RANDOM** - Natural, chaotic shattering
2. **GRID** - Organized rectangular fragments (good for walls/tiles)
3. **RADIAL** - Circular impact pattern from center
4. **SPIDERWEB** - Glass-like shattering pattern
5. **POISSON_DISK** - Even distribution with natural variation

### Creating Custom CutoutMesh

```gdscript
# In destructible_cutout.gd _ready():
var cutout_mesh = CutoutMesh.new()
cutout_mesh.texture = preload("res://examples/destruction/target_texture.png")

# Define polygon (clockwise winding)
var outer_polygon = PackedVector2Array([
    Vector2(0, 0),
    Vector2(100, 0),
    Vector2(100, 100),
    Vector2(0, 100)
])

# Optional: Add holes
var hole = PackedVector2Array([
    Vector2(25, 25),
    Vector2(75, 25),
    Vector2(75, 75),
    Vector2(25, 75)
])

cutout_mesh.mask = [outer_polygon, hole]  # First is boundary, rest are holes
cutout_mesh.depth = 0.5  # Extrusion depth
cutout_mesh.mesh_size = Vector2(2, 2)  # World size

$CutoutMeshInstance3D.cutout_mesh = cutout_mesh
```

### Adding Visual Effects

For particle effects on destruction:

```gdscript
# In spawn_fragment():
var particles = GPUParticles3D.new()
particles.amount = 50
particles.lifetime = 0.5
particles.one_shot = true
particles.emitting = true
fragment.add_child(particles)
```

## Technical Notes

### How Destruction Works

1. **Polygon Extraction**: The original CutoutMesh's polygon mask is extracted
2. **Voronoi Fracturing**: CutoutDestructionVoronoi subdivides the polygon into fragments
3. **Mesh Generation**: Each fragment polygon becomes a new CutoutMesh
4. **Physics Conversion**: Fragments are wrapped in RigidBody3D nodes
5. **Force Application**: Explosion forces push fragments outward from impact point
6. **Cleanup**: Fragments fade and delete after their lifetime expires

### Performance Considerations

- **Fragment Count**: More fragments = higher CPU/physics load
- **Collision Shapes**: Trimesh collisions are accurate but expensive
- **Lifetime**: Shorter lifetimes prevent fragment buildup
- **LOD**: Consider disabling shadows on fragments for better performance

### Common Issues and Solutions

**Problem**: Fragments fall through the ground
**Solution**: Ensure ground has proper collision shape and layers match

**Problem**: Destruction looks unrealistic
**Solution**: Adjust explosion_force and add rotational impulses

**Problem**: Performance drops with many fragments
**Solution**: Reduce fragment_count or use simpler collision shapes

**Problem**: Fragments don't match original texture
**Solution**: Ensure UV coordinates are preserved in CutoutMesh generation

## Future Enhancements

- Multiple destructible objects in scene
- Chain reaction destruction
- Different materials with varying destruction behaviors
- Fragment pooling for better performance
- Save/load destruction states
- Slow-motion effect during destruction
- Different interaction methods (shooting, punching, etc.)
- Environmental damage (fragments damaging other objects)

## Credits

Built using the Cutout plugin's polygon destruction system with CutoutDestructionVoronoi algorithm.