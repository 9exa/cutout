@tool
extends Node3D

## Test script to verify that multiple CutoutMeshInstance3D nodes
## can share a single CutoutMesh resource efficiently.

@export var test_texture: Texture2D

@export_group("Test Controls")
@export var create_shared_instances: bool = false:
	set(value):
		if value and test_texture:
			_test_shared_instances()
		create_shared_instances = false

@export var create_unique_instances: bool = false:
	set(value):
		if value and test_texture:
			_test_unique_instances()
		create_unique_instances = false

@export var clear_instances: bool = false:
	set(value):
		if value:
			_clear_all_instances()
		clear_instances = false

var _instance_counter: int = 0


func _test_shared_instances() -> void:
	print("\n=== Testing Shared CutoutMesh (Mesh + Materials) ===")

	# Create ONE CutoutMesh resource
	var shared_mesh := CutoutMesh.create_from_texture(
		test_texture,
		0.5,  # alpha_threshold
		2.0,  # detail_threshold
		null, # no smoothing
		0.15  # depth
	)

	if not shared_mesh:
		push_error("Failed to create CutoutMesh")
		return

	# Set material properties on the SHARED resource
	shared_mesh.side_color = Color(0.8, 0.6, 0.4)  # All instances will have this color

	print("Created shared CutoutMesh resource")
	print("  Texture: ", test_texture.resource_path)
	print("  Mask polygons: ", shared_mesh.mask.size())
	print("  Mesh size: ", shared_mesh.mesh_size)
	print("  Side color: ", shared_mesh.side_color)

	# Create multiple instances sharing the same mesh AND materials
	var instance_count := 5
	var spacing := 3.0

	for i in range(instance_count):
		var instance := CutoutMeshInstance3D.new()
		instance.name = "SharedInstance_%d" % _instance_counter
		_instance_counter += 1

		# Share the same CutoutMesh resource (mesh + materials)
		instance.cutout_mesh = shared_mesh

		# Position in a row
		instance.position = Vector3(i * spacing, 0, 0)

		add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = get_tree().edited_scene_root

		print("  Created instance %d at position %s" % [i, instance.position])

	print("Successfully created %d instances sharing ONE CutoutMesh" % instance_count)
	print("  - 1 ArrayMesh shared across all instances")
	print("  - 1 Face Material shared across all instances")
	print("  - 1 Side Material shared across all instances")
	print("  - Total: 3 resources for %d instances = Maximum efficiency!" % instance_count)
	print("=== Test Complete ===\n")


func _test_unique_instances() -> void:
	print("\n=== Testing Unique CutoutMesh (for comparison) ===")

	# Create multiple instances, each with its OWN CutoutMesh resource
	var instance_count := 5
	var spacing := 3.0

	for i in range(instance_count):
		# Create UNIQUE CutoutMesh for each instance
		var unique_mesh := CutoutMesh.create_from_texture(
			test_texture,
			0.5,
			2.0,
			null,
			0.15
		)

		if not unique_mesh:
			push_error("Failed to create CutoutMesh for instance %d" % i)
			continue

		# Each instance has unique color
		var hue := float(i) / float(instance_count)
		unique_mesh.side_color = Color.from_hsv(hue, 0.8, 0.8)

		var instance := CutoutMeshInstance3D.new()
		instance.name = "UniqueInstance_%d" % _instance_counter
		_instance_counter += 1

		# Each instance has its OWN CutoutMesh (wasteful for identical meshes!)
		instance.cutout_mesh = unique_mesh

		# Position in a row (offset to not overlap with shared instances)
		instance.position = Vector3(i * spacing, 0, 5)

		add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = get_tree().edited_scene_root

		print("  Created instance %d with UNIQUE CutoutMesh and color %s" % [i, unique_mesh.side_color])

	print("Successfully created %d instances, each with unique CutoutMesh" % instance_count)
	print("  - %d ArrayMeshes (one per instance)" % instance_count)
	print("  - %d Face Materials (one per instance)" % instance_count)
	print("  - %d Side Materials (one per instance)" % instance_count)
	print("  - Total: %d resources for %d instances = Wasteful if meshes are identical!" % [instance_count * 3, instance_count])
	print("WARNING: Only use unique CutoutMesh if instances need different shapes/textures")
	print("=== Test Complete ===\n")


func _clear_all_instances() -> void:
	print("\n=== Clearing All Instances ===")
	var removed_count := 0

	# Remove all CutoutMeshInstance3D children
	for child in get_children():
		if child is CutoutMeshInstance3D:
			child.queue_free()
			removed_count += 1

	_instance_counter = 0
	print("Removed %d instances" % removed_count)
	print("=== Clear Complete ===\n")
