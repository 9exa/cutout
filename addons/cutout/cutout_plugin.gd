@tool
extends EditorPlugin

const CutoutDock = preload("res://addons/cutout/ui/cutout_dock.tscn")
var dock_instance

func _enter_tree() -> void:
	# Register the CardboardCutout node as a custom node type
	add_custom_type(
		"CardboardCutout",           # Node name as it appears in the Create Node dialog
		"Node3D",                    # Base class
		preload("nodes/cardboard_cutout.gd"),  # Script resource
		preload("res://addons/cutout/nodes/cardboard_cutout.svg")  # Icon (optional)
	)
	print("Cutout plugin: CardboardCutout node registered")

	# Register the CutoutMeshInstance3D node
	add_custom_type(
		"CutoutMeshInstance3D",
		"Node3D",
		preload("nodes/cutout_mesh_instance_3d.gd"),
		preload("res://addons/cutout/nodes/cardboard_cutout.svg")  # Reuse same icon for now
	)
	print("Cutout plugin: CutoutMeshInstance3D node registered")

	# Create and add the editor dock
	dock_instance = CutoutDock.instantiate()
	add_control_to_bottom_panel(dock_instance, "Cutout")
	print("Cutout plugin: Editor dock added")


func _exit_tree() -> void:
	# Clean up the custom node types when plugin is disabled
	remove_custom_type("CardboardCutout")
	remove_custom_type("CutoutMeshInstance3D")

	# Remove the editor dock
	if dock_instance:
		remove_control_from_bottom_panel(dock_instance)
		dock_instance.queue_free()
		dock_instance = null

	print("Cutout plugin: CardboardCutout and CutoutMeshInstance3D nodes unregistered and dock removed")
