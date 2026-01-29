extends Node3D

## Main controller for the destruction showcase scene
## Manages UI, scene reset, and debug controls

# Preload scripts
const PlayerController = preload("res://examples/destruction/player_controller.gd")
const InteractionSystem = preload("res://examples/destruction/interaction_system.gd")
const DestructibleCutout = preload("res://examples/destruction/destructible_cutout.gd")
const CutoutDestructionVoronoi = preload("res://addons/cutout/resources/destruction/cutout_destruction_voronoi.gd")
const CutoutDestructionSlice = preload("res://addons/cutout/resources/destruction/cutout_destruction_slice.gd")
const CutoutDestructionSlices = preload("res://addons/cutout/resources/destruction/cutout_destruction_slices.gd")
const CutoutMesh = preload("res://addons/cutout/resources/cutout_mesh.gd")
const CutoutMeshInstance3D = preload("res://addons/cutout/nodes/cutout_mesh_instance_3d.gd")

# Scene references
@export_group("Scene References")
@export var destructible_scene: PackedScene
@export var player_scene: PackedScene
@export var destructible_spawn_position: Vector3 = Vector3(0, 1, -5)
@export var player_spawn_position: Vector3 = Vector3(0, 1, 0)

# UI references
@export_group("UI References")
@export var crosshair_label: Label
@export var interaction_prompt_label: Label
@export var debug_info_label: RichTextLabel
@export var pattern_label: Label
@export var controls_panel: Panel

# Settings
@export_group("Settings")
@export var show_fps: bool = true
@export var show_debug_info: bool = true
@export var show_controls_on_start: bool = true
@export var auto_respawn_delay: float = -1.0  # -1 to disable

# Destruction settings
@export_group("Destruction Algorithms")
@export var destruction_algorithms: Array[CutoutDestructionAlgorithm] = []

# Runtime references
var current_destructible: Node3D
var player_controller: Node
var interaction_system: Node
var fragments_cleared: bool = false
var current_algorithm_index: int = 0

# Statistics
var destruction_count: int = 0
var current_fragment_count: int = 0
var total_fragments_spawned: int = 0


func _ready() -> void:
	# Setup UI
	setup_ui()

	# Spawn initial objects
	spawn_player()
	spawn_destructible()

	# Show controls briefly at start
	if show_controls_on_start:
		show_controls_temporarily()

	# Setup input mapping if not already configured
	setup_input_mapping()


func setup_ui() -> void:
	# Create UI if references aren't set
	if not crosshair_label:
		crosshair_label = create_crosshair()

	if not interaction_prompt_label:
		interaction_prompt_label = create_interaction_prompt()

	if not debug_info_label:
		debug_info_label = create_debug_info()

	if not pattern_label:
		pattern_label = create_pattern_label()

	if not controls_panel:
		controls_panel = create_controls_panel()


func create_crosshair() -> Label:
	var canvas := get_canvas_layer()
	var label := Label.new()
	label.name = "Crosshair"
	label.text = "+"
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	canvas.add_child(label)
	return label


func create_interaction_prompt() -> Label:
	var canvas := get_canvas_layer()
	var label := Label.new()
	label.name = "InteractionPrompt"
	label.text = ""
	label.add_theme_font_size_override("font_size", 18)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.position.y = 40
	label.visible = false
	canvas.add_child(label)
	return label


func create_debug_info() -> RichTextLabel:
	var canvas := get_canvas_layer()
	var label := RichTextLabel.new()
	label.name = "DebugInfo"
	label.bbcode_enabled = true
	label.fit_content = true
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(10, 10)
	label.size = Vector2(300, 200)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	return label


func create_pattern_label() -> Label:
	var canvas := get_canvas_layer()
	var label := Label.new()
	label.name = "PatternLabel"
	label.text = "Pattern: Random"
	label.add_theme_font_size_override("font_size", 16)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.position = Vector2(-200, 10)
	canvas.add_child(label)
	return label


func create_controls_panel() -> Panel:
	var canvas := get_canvas_layer()
	var panel := Panel.new()
	panel.name = "ControlsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(10, -250)
	panel.size = Vector2(350, 240)
	panel.visible = false

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.text = get_controls_text()
	label.position = Vector2(10, 10)
	label.size = Vector2(330, 220)
	panel.add_child(label)

	canvas.add_child(panel)
	return panel


func get_controls_text() -> String:
	return "[b]Controls:[/b]
[color=yellow]Movement:[/color]
  WASD - Move
  Mouse - Look around
  Space - Jump
  Shift - Sprint

[color=yellow]Interaction:[/color]
  E - Destroy object
  R - Reset scene
  Tab - Cycle destruction pattern

[color=yellow]UI:[/color]
  F1 - Toggle controls
  F2 - Toggle debug info
  Escape - Release mouse"


func get_canvas_layer() -> CanvasLayer:
	# Find or create CanvasLayer
	var canvas := get_node_or_null("UI") as CanvasLayer
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "UI"
		add_child(canvas)
	return canvas


func setup_input_mapping() -> void:
	# Ensure all required input actions exist
	var actions := {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"reset_scene": KEY_R,
		"cycle_pattern": KEY_TAB,
		"toggle_controls": KEY_F1,
		"toggle_debug": KEY_F2
	}

	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.keycode = actions[action]
			InputMap.action_add_event(action, event)


func spawn_player() -> void:
	if not player_scene:
		# Create player manually if no scene provided
		var player := CharacterBody3D.new()
		player.name = "Player"
		player.position = player_spawn_position

		# Add controller script
		player.set_script(PlayerController)

		# Add components
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		collision.shape = shape
		player.add_child(collision)

		var head := Node3D.new()
		head.name = "Head"
		head.position.y = 0.7
		player.add_child(head)

		var camera := Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = 75
		head.add_child(camera)

		# Add interaction system to camera
		var interaction_node := Node.new()
		interaction_node.name = "InteractionSystem"
		interaction_node.set_script(InteractionSystem)
		camera.add_child(interaction_node)

		# Store reference and add to scene
		interaction_system = interaction_node
		add_child(player)

		# Set UI references
		interaction_node.interaction_prompt_path = interaction_node.get_path_to(interaction_prompt_label)
		interaction_node.crosshair_path = interaction_node.get_path_to(crosshair_label)
	else:
		var player := player_scene.instantiate()
		player.position = player_spawn_position
		add_child(player)

		# Find interaction system in player
		interaction_system = player.get_node_or_null("Head/Camera3D/InteractionSystem")


func spawn_destructible() -> void:
	# Clear any existing destructible
	if current_destructible:
		current_destructible.queue_free()
		current_destructible = null

	if not destructible_scene:
		# Create destructible manually if no scene provided
		current_destructible = create_default_destructible()
	else:
		current_destructible = destructible_scene.instantiate()

	current_destructible.position = destructible_spawn_position
	add_child(current_destructible)

	# Set initial algorithm if available
	if not destruction_algorithms.is_empty() and current_destructible.has_method("set_destruction_algorithm"):
		current_destructible.set_destruction_algorithm(destruction_algorithms[current_algorithm_index])

	# Connect to destruction signal if available
	if current_destructible.has_signal("destroyed"):
		current_destructible.destroyed.connect(_on_destructible_destroyed.bind(current_destructible))


func create_default_destructible() -> Node3D:
	var destructible := Node3D.new()
	destructible.name = "DestructibleCutout"

	# Add destructible script
	destructible.set_script(DestructibleCutout)

	# Create CutoutMeshInstance3D
	var mesh_instance := Node3D.new()
	mesh_instance.name = "CutoutMeshInstance3D"
	mesh_instance.set_script(CutoutMeshInstance3D)

	# Create a simple square cutout mesh
	var cutout_mesh: Resource = CutoutMesh.new()

	# Create a simple white texture
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	cutout_mesh.texture = texture

	# Define a star-shaped polygon for interesting destruction
	var outer_polygon := create_star_polygon(Vector2(128, 128), 100, 60, 8)
	cutout_mesh.mask = [outer_polygon]
	cutout_mesh.depth = 0.3
	cutout_mesh.mesh_size = Vector2(2, 2)

	# Assign mesh to instance
	mesh_instance.set("cutout_mesh", cutout_mesh)
	destructible.add_child(mesh_instance)

	# Add static body for interaction
	var static_body := StaticBody3D.new()
	static_body.name = "StaticBody3D"

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.3)
	collision.shape = shape
	static_body.add_child(collision)
	destructible.add_child(static_body)

	# Add audio player
	var audio_player := AudioStreamPlayer3D.new()
	audio_player.name = "AudioStreamPlayer3D"
	destructible.add_child(audio_player)

	return destructible


func create_star_polygon(center: Vector2, outer_radius: float, inner_radius: float, points: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var angle_step := TAU / (points * 2)

	for i in range(points * 2):
		var angle := i * angle_step - PI / 2
		var radius := outer_radius if i % 2 == 0 else inner_radius
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		polygon.append(point)

	return polygon


func _process(_delta: float) -> void:
	update_debug_info()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_scene"):
		reset_scene()
	elif event.is_action_pressed("cycle_pattern"):
		cycle_destruction_pattern()
	elif event.is_action_pressed("toggle_controls"):
		toggle_controls_panel()
	elif event.is_action_pressed("toggle_debug"):
		toggle_debug_info()


func update_debug_info() -> void:
	if not debug_info_label or not show_debug_info:
		return

	var fps: int = Engine.get_frames_per_second() if show_fps else 0
	var pattern_name: String = get_current_algorithm_name()

	var text := ""
	if show_fps:
		text += "[color=green]FPS: %d[/color]\n" % fps

	text += "[color=aqua]Pattern: %s[/color]\n" % pattern_name
	text += "[color=yellow]Destructions: %d[/color]\n" % destruction_count
	text += "[color=cyan]Active Fragments: %d[/color]\n" % current_fragment_count
	text += "[color=magenta]Total Fragments: %d[/color]" % total_fragments_spawned

	debug_info_label.text = text


func reset_scene() -> void:
	# Clear all fragments
	clear_all_fragments()

	# Reset destructible
	if current_destructible and current_destructible.has_method("reset"):
		current_destructible.reset()
	else:
		spawn_destructible()

	# Update UI
	if pattern_label:
		pattern_label.text = "Pattern: " + get_current_algorithm_name()


func get_current_algorithm_name() -> String:
	if destruction_algorithms.is_empty():
		return "None"

	if current_algorithm_index >= destruction_algorithms.size():
		return "Invalid Index"

	return get_algorithm_name(destruction_algorithms[current_algorithm_index])


func get_algorithm_name(algorithm: CutoutDestructionAlgorithm) -> String:
	if algorithm == null:
		return "None"

	# Check algorithm type
	if algorithm is CutoutDestructionVoronoi:
		var voronoi := algorithm as CutoutDestructionVoronoi
		match voronoi.pattern:
			CutoutDestructionVoronoi.SeedPattern.RANDOM:
				return "Voronoi: Random"
			CutoutDestructionVoronoi.SeedPattern.GRID:
				return "Voronoi: Grid"
			CutoutDestructionVoronoi.SeedPattern.RADIAL:
				return "Voronoi: Radial"
			CutoutDestructionVoronoi.SeedPattern.SPIDERWEB:
				return "Voronoi: Spiderweb"
			CutoutDestructionVoronoi.SeedPattern.POISSON_DISK:
				return "Voronoi: Poisson Disk"
			_:
				return "Voronoi: Unknown"
	elif algorithm is CutoutDestructionSlice:
		return "Slice"
	elif algorithm is CutoutDestructionSlices:
		var slices := algorithm as CutoutDestructionSlices
		match slices.pattern:
			CutoutDestructionSlices.Pattern.PARALLEL:
				return "Slices: Parallel"
			CutoutDestructionSlices.Pattern.RADIAL:
				return "Slices: Radial"
			CutoutDestructionSlices.Pattern.GRID:
				return "Slices: Grid"
			_:
				return "Slices: Unknown"
	else:
		# Generic fallback - use the class name
		return algorithm.get_class().replace("CutoutDestruction", "")


func cycle_destruction_pattern() -> void:
	if not current_destructible or destruction_algorithms.is_empty():
		return

	# Cycle to next algorithm in the array
	current_algorithm_index = (current_algorithm_index + 1) % destruction_algorithms.size()
	var algorithm := destruction_algorithms[current_algorithm_index]

	# Set the algorithm on the destructible
	if current_destructible.has_method("set_destruction_algorithm"):
		current_destructible.set_destruction_algorithm(algorithm)

	# Update UI
	if pattern_label:
		pattern_label.text = "Pattern: " + get_algorithm_name(algorithm)


func clear_all_fragments() -> void:
	# Find and remove all fragment nodes
	var fragments := get_tree().get_nodes_in_group("fragments")
	for fragment in fragments:
		fragment.queue_free()

	# Also clear from destructible's fragment container
	var container := get_node_or_null("Fragments")
	if container:
		for child in container.get_children():
			child.queue_free()

	current_fragment_count = 0


func toggle_controls_panel() -> void:
	if controls_panel:
		controls_panel.visible = !controls_panel.visible


func toggle_debug_info() -> void:
	show_debug_info = !show_debug_info
	if debug_info_label:
		debug_info_label.visible = show_debug_info


func show_controls_temporarily() -> void:
	if not controls_panel:
		return

	controls_panel.visible = true
	await get_tree().create_timer(5.0).timeout
	controls_panel.visible = false


func _on_destructible_destroyed(destructible: Node) -> void:
	destruction_count += 1

	# Count new fragments
	if destructible.has_method("get_fragment_count"):
		var new_fragments: int = destructible.get_fragment_count()
		current_fragment_count += new_fragments
		total_fragments_spawned += new_fragments

	# Auto-respawn if enabled
	if auto_respawn_delay > 0:
		await get_tree().create_timer(auto_respawn_delay).timeout
		reset_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
