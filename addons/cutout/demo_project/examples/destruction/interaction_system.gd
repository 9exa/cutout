extends Node

## Interaction system that handles raycast detection and object interaction
## Attach this to the Camera3D node in the player

# Interaction settings
@export_group("Interaction")
@export var interaction_range: float = 5.0
@export var interact_key: String = "interact"  # Default mapped to 'E'
@export var show_debug_ray: bool = false

# UI references (set in scene)
@export_group("UI References")
@export var interaction_prompt_path: NodePath
@export var crosshair_path: NodePath

# Cached references
var interaction_prompt: Control
var crosshair: Control
var camera: Camera3D
var current_interactable: Node = null
var last_interactable: Node = null

# Signals
signal interaction_started(target: Node)
signal interaction_ended(target: Node)
signal interactable_focused(target: Node)
signal interactable_unfocused(target: Node)


func _ready() -> void:
	# Get camera reference (parent should be Camera3D)
	camera = get_parent() as Camera3D
	if not camera:
		push_error("InteractionSystem must be attached to a Camera3D node!")
		return

	# Get UI references if paths are set
	if interaction_prompt_path:
		interaction_prompt = get_node(interaction_prompt_path)
		if interaction_prompt:
			interaction_prompt.visible = false

	if crosshair_path:
		crosshair = get_node(crosshair_path)


func _physics_process(_delta: float) -> void:
	if not camera:
		return

	check_interaction()


func check_interaction() -> void:
	# Cast ray from camera center
	var ray_result := cast_interaction_ray()

	# Check if we hit an interactable object
	if ray_result and ray_result.collider:
		var target = find_interactable_parent(ray_result.collider)

		if target:
			# New interactable focused
			if target != current_interactable:
				if current_interactable:
					on_interactable_unfocused(current_interactable)
				on_interactable_focused(target)
				current_interactable = target

			# Check for interaction input
			if Input.is_action_just_pressed(interact_key):
				interact_with(target)
		else:
			# Hit something but it's not interactable
			clear_current_interactable()
	else:
		# Didn't hit anything
		clear_current_interactable()


func cast_interaction_ray() -> Dictionary:
	# Get viewport and world
	var viewport := get_viewport()
	var world := viewport.world_3d
	var space_state := world.direct_space_state

	# Calculate ray from camera center
	var from := camera.global_position
	var to := from + camera.global_transform.basis * Vector3(0, 0, -interaction_range)

	# Create ray query
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_parent().get_parent()]  # Exclude the player

	# Perform raycast
	var result := space_state.intersect_ray(query)

	# Debug visualization
	if show_debug_ray and result:
		draw_debug_ray(from, result.position)

	return result


func find_interactable_parent(node: Node) -> Node:
	# Check if the node itself is interactable
	if node.has_method("can_interact") and node.can_interact():
		return node

	# Check parent nodes up to a reasonable depth
	var current := node
	var depth := 0
	var max_depth := 5

	while current and depth < max_depth:
		current = current.get_parent()
		if current and current.has_method("can_interact") and current.can_interact():
			return current
		depth += 1

	return null


func interact_with(target: Node) -> void:
	if not target:
		return

	# Call interact method on target
	if target.has_method("interact"):
		target.interact()
		interaction_started.emit(target)

		# Hide prompt temporarily after interaction
		if interaction_prompt:
			interaction_prompt.visible = false

		# Clear current interactable to reset state
		current_interactable = null


func on_interactable_focused(target: Node) -> void:
	# Show interaction prompt
	if interaction_prompt:
		var prompt_text := "Press E to Interact"

		# Check if target has custom prompt text
		if target.has_method("get_interaction_prompt"):
			prompt_text = target.get_interaction_prompt()

		if interaction_prompt is Label:
			interaction_prompt.text = prompt_text
		elif interaction_prompt is RichTextLabel:
			interaction_prompt.text = prompt_text

		interaction_prompt.visible = true

	# Change crosshair appearance (optional)
	if crosshair and crosshair.has_method("set_active"):
		crosshair.set_active(true)

	# Notify target it's being focused
	if target.has_method("on_focus_entered"):
		target.on_focus_entered()

	interactable_focused.emit(target)


func on_interactable_unfocused(target: Node) -> void:
	# Hide interaction prompt
	if interaction_prompt:
		interaction_prompt.visible = false

	# Reset crosshair appearance (optional)
	if crosshair and crosshair.has_method("set_active"):
		crosshair.set_active(false)

	# Notify target it's no longer focused
	if target.has_method("on_focus_exited"):
		target.on_focus_exited()

	interactable_unfocused.emit(target)


func clear_current_interactable() -> void:
	if current_interactable:
		on_interactable_unfocused(current_interactable)
		current_interactable = null


func draw_debug_ray(from: Vector3, to: Vector3) -> void:
	# This would need to be implemented with a debug draw system
	# For now, just print the ray info
	pass


func set_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	if not enabled:
		clear_current_interactable()


func get_current_interactable() -> Node:
	return current_interactable


func force_interact() -> void:
	# Force interaction with current target (useful for gamepad/alternative inputs)
	if current_interactable:
		interact_with(current_interactable)