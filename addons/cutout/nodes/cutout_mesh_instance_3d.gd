@tool
class_name CutoutMeshInstance3D
extends Node3D

## 3D display node for CutoutMesh resources.
##
## This node renders a CutoutMesh resource and allows per-instance customization
## of materials (side color, extrusion texture). Multiple instances can share
## the same CutoutMesh resource for efficient memory usage and performance.
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

## Internal mesh instance for rendering
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_setup_mesh_instance()
	if cutout_mesh:
		_update_mesh()


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

	# Use shared material from CutoutMesh for surface 0 (faces)
	_mesh_instance.set_surface_override_material(0, cutout_mesh.get_face_material())

	# Use shared material from CutoutMesh for surface 1 (sides)
	if mesh.get_surface_count() >= 2:
		_mesh_instance.set_surface_override_material(1, cutout_mesh.get_side_material())


func _on_cutout_mesh_changed() -> void:
	_update_mesh()
