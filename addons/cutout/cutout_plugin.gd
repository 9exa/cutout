@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Register the CardboardCutout node as a custom node type
	add_custom_type(
		"CardboardCutout",           # Node name as it appears in the Create Node dialog
		"Node3D",                    # Base class
		preload("nodes/cardboard_cutout.gd"),  # Script resource
		preload("res://addons/cutout/nodes/cardboard_cutout.svg")  # Icon (optional)
	)
	print("Cutout plugin: CardboardCutout node registered")


func _exit_tree() -> void:
	# Clean up the custom node type when plugin is disabled
	remove_custom_type("CardboardCutout")
	print("Cutout plugin: CardboardCutout node unregistered")
