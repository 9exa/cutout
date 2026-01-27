@tool
class_name CutoutMeshInstance3D
extends Node3D

## 3D display node for CutoutMesh resources.
##
## This node renders a CutoutMesh resource and supports per-instance material customization
## via optional material overrides. Multiple instances can share the same CutoutMesh resource
## for efficient memory usage and performance.
##
## By default, uses auto-generated materials from CutoutMesh (based on texture and extrusion_texture).
## For advanced use cases (custom shaders, animations, special effects), you can override materials
## per-instance using [member override_face_material] and [member override_extrusion_material].
##
## The actual mesh rendering is handled by an internal MeshInstance3D child node,
## keeping the implementation details encapsulated.

## The CutoutMesh resource to display.
## Multiple CutoutMeshInstance3D nodes can share the same CutoutMesh.
## The mesh AND materials are shared for maximum performance.
@export var cutout_mesh: CutoutMesh:
	set(value):
		# Disconnect from old resource
		if cutout_mesh and cutout_mesh.changed.is_connected(_on_cutout_mesh_changed):
			cutout_mesh.changed.disconnect(_on_cutout_mesh_changed)

		cutout_mesh = value

		# Connect to new resource
		if cutout_mesh:
			cutout_mesh.changed.connect(_on_cutout_mesh_changed)
			_update_mesh()

## Optional material override for front and back faces (Surface 0).
## If set, this material replaces the auto-generated face material from CutoutMesh.
## The face surface uses standard UV mapping (0-1 range) from the texture.
##
## Background Material Example:
## To show a background material where texture alpha is 0 or texture is null,
## use the included shader: res://addons/cutout/shaders/cutout_background_composite.tres
##   1. Duplicate the shader material resource
##   2. Set 'foreground_texture' to your main texture
##   3. Set 'background_color' or enable 'use_background_texture' with 'background_texture'
##   4. Assign the material to this property
##
## Set to null to revert to the auto-generated material.
@export var override_face_material: Material:
	set(value):
		override_face_material = value
		if is_node_ready():
			_update_materials()

## Optional material override for extrusion side walls (Surface 1).
## If set, this material replaces the auto-generated extrusion material from CutoutMesh.
##
## UV Coordinates for custom shaders:
##   UV.x: Distance along perimeter (0.0 to perimeter_length * extrusion_texture_scale)
##         - Exceeds 1.0 to enable seamless tiling around irregular shapes
##         - Use fract(UV.x) to normalize to 0-1 range if needed
##   UV.y: Depth position (0.0 = front face, 1.0 = back face)
##         - Always in 0-1 range
##
## Example shader for scrolling animation:
##   shader_type spatial;
##   uniform sampler2D my_texture;
##   void fragment() {
##       vec2 uv = UV;
##       uv.x += TIME * 0.5;  // Scroll along perimeter
##       ALBEDO = texture(my_texture, uv).rgb;
##   }
##
## Set to null to revert to the auto-generated material.
@export var override_extrusion_material: Material:
	set(value):
		override_extrusion_material = value
		if is_node_ready():
			_update_materials()

## Internal mesh instance for rendering
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_setup_mesh_instance()
	if cutout_mesh:
		_update_mesh()

func get_mesh_instance() -> MeshInstance3D:
	if not _mesh_instance:
		_setup_mesh_instance()
	return _mesh_instance

func _setup_mesh_instance() -> void:
	# Try to find existing internal MeshInstance3D child first
	if not _mesh_instance and is_inside_tree() and is_node_ready():
		if has_node("__CutoutMesh__"):
			_mesh_instance = get_node("__CutoutMesh__")

	# Create new one only if none exists
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "__CutoutMesh__"
		add_child(_mesh_instance)

		# Set owner for editor visibility
		if Engine.is_editor_hint() and is_inside_tree():
			var root := get_tree().edited_scene_root
			if root:
				_mesh_instance.owner = root

		# Make visible in editor
		_mesh_instance.set_meta("_edit_lock_", false)


func _update_mesh() -> void:
	if not is_node_ready():
		return

	if not _mesh_instance:
		_setup_mesh_instance()

	if not cutout_mesh:
		_mesh_instance.mesh = null
		return

	# Get mesh from CutoutMesh resource (cached internally)
	_mesh_instance.mesh = cutout_mesh.get_mesh()
	_update_materials()


func _update_materials() -> void:
	if not _mesh_instance or not _mesh_instance.mesh or not cutout_mesh:
		return

	var mesh := _mesh_instance.mesh
	if mesh.get_surface_count() < 1:
		return

	# Surface 0: Front and back faces
	# Use override if provided, otherwise use shared material from CutoutMesh
	if override_face_material:
		_mesh_instance.set_surface_override_material(0, override_face_material)
	else:
		_mesh_instance.set_surface_override_material(0, cutout_mesh.get_face_material())

	# Surface 1: Extrusion side walls
	# Use override if provided, otherwise use shared material from CutoutMesh
	if mesh.get_surface_count() >= 2:
		if override_extrusion_material:
			_mesh_instance.set_surface_override_material(1, override_extrusion_material)
		else:
			_mesh_instance.set_surface_override_material(1, cutout_mesh.get_side_material())


func _on_cutout_mesh_changed() -> void:
	_update_mesh()
