@tool
extends Node3D

## Example script showing basic CutoutMeshInstance3D usage.
## This demonstrates how to create a shared CutoutMesh and spawn multiple instances.

@export var character_texture: Texture2D:
	set(value):
		character_texture = value
		_regenerate_example()

@export var spawn_count: int = 3:
	set(value):
		spawn_count = max(1, value)
		_regenerate_example()

@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5:
	set(value):
		alpha_threshold = value
		_regenerate_example()

@export_range(0.5, 10.0, 0.1) var detail_threshold: float = 2.0:
	set(value):
		detail_threshold = value
		_regenerate_example()

@export var side_color: Color = Color(0.7, 0.6, 0.5):
	set(value):
		side_color = value
		if _shared_cutout_mesh:
			_shared_cutout_mesh.side_color = value

@export var regenerate: bool = false:
	set(value):
		if value:
			_regenerate_example()
		regenerate = false

var _shared_cutout_mesh: CutoutMesh
var _instances: Array[CutoutMeshInstance3D] = []


func _ready() -> void:
	if character_texture and get_child_count() == 0:
		_regenerate_example()


func _regenerate_example() -> void:
	if not character_texture:
		return

	# Clear existing instances
	for instance in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	_instances.clear()

	# Create ONE shared CutoutMesh resource
	_shared_cutout_mesh = CutoutMesh.create_from_texture(
		character_texture,
		alpha_threshold,
		detail_threshold,
		null,  # No smoothing for simplicity
		0.15   # depth
	)

	if not _shared_cutout_mesh:
		push_warning("Failed to create CutoutMesh")
		return

	# Set material properties
	_shared_cutout_mesh.side_color = side_color

	# Create multiple instances in a row
	var spacing := 3.0
	for i in range(spawn_count):
		var instance := CutoutMeshInstance3D.new()
		instance.name = "Character_%d" % i
		instance.cutout_mesh = _shared_cutout_mesh  # Share the same resource
		instance.position = Vector3(i * spacing - (spawn_count - 1) * spacing * 0.5, 0, 0)

		add_child(instance)
		if Engine.is_editor_hint() and is_inside_tree():
			instance.owner = get_tree().edited_scene_root

		_instances.append(instance)

	print("Created %d instances sharing ONE CutoutMesh" % spawn_count)
