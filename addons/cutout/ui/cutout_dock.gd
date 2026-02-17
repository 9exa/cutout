@tool
extends Control

signal cutout_mesh_created(mesh: CutoutMesh)

## Image Section Controls
@export_group("Image Section")
@export var image_selector_button: Button
@export var image_path_label: Label

## Contour Algorithm Controls
@export_group("Contour Algorithm")
@export var contour_section: VBoxContainer
@export var contour_section_button: Button  # Collapse/expand button
@export var contour_section_content: VBoxContainer  # Content container
@export var contour_algorithm_option: OptionButton
@export var contour_params: VBoxContainer

## Pre-Simplification Controls
@export_group("Pre-Simplification")
@export var pre_simp_section: VBoxContainer
@export var pre_simp_section_button: Button  # Collapse/expand button
@export var pre_simp_section_content: VBoxContainer  # Content container
@export var pre_simp_algorithm_option: OptionButton
@export var pre_simp_params: VBoxContainer

## Smoothing Controls
@export_group("Smoothing")
@export var smooth_section: VBoxContainer
@export var smooth_section_button: Button  # Collapse/expand button
@export var smooth_section_content: VBoxContainer  # Content container
@export var smooth_algorithm_option: OptionButton
@export var smooth_params: VBoxContainer

## Post-Simplification Controls
@export_group("Post-Simplification")
@export var post_simp_section: VBoxContainer
@export var post_simp_section_button: Button  # Collapse/expand button
@export var post_simp_section_content: VBoxContainer  # Content container
@export var post_simp_algorithm_option: OptionButton
@export var post_simp_params: VBoxContainer

## Preview Controls
@export_group("Preview")
@export var preview_tab_container: TabContainer
@export var preview_container_2d: SubViewportContainer
@export var preview_viewport_2d: SubViewport
@export var preview_camera_2d: PanZoomCamera2D
@export var polygon_preview: Node2D
@export var preview_container_3d: SubViewportContainer
@export var preview_viewport_3d: SubViewport
@export var mesh_preview_3d: MeshPreview3D
@export var orbit_camera_3d: OrbitCamera3D

## Mesh Settings Controls
@export_group("Mesh Settings")
@export var mesh_settings_section: VBoxContainer
@export var mesh_settings_button: Button  # Collapse/expand button
@export var mesh_settings_content: VBoxContainer  # Content container
@export var depth_slider: HSlider
@export var depth_value: Label
@export var mesh_width_spinbox: SpinBox
@export var mesh_height_spinbox: SpinBox

## Export Controls
@export_group("Export")
@export var export_button: Button
@export var export_path_line: LineEdit

# Algorithm instances
var current_texture: Texture2D
var current_image: Image

# Live 3D preview mesh
var _preview_cutout_mesh: CutoutMesh

var contour_algorithm: CutoutContourAlgorithm
var pre_simp_algorithm: CutoutPolysimpAlgorithm
var smooth_algorithm: CutoutSmoothAlgorithm
var post_simp_algorithm: CutoutPolysimpAlgorithm

# Cached algorithm lists from registry (for dropdown index mapping)
var _contour_algorithms: Array = []
var _polysimp_algorithms: Array = []
var _smooth_algorithms: Array = []

# Pipeline results - intermediate polygons for incremental computation
var contour_polygon: PackedVector2Array = PackedVector2Array()
var pre_simp_polygon: PackedVector2Array = PackedVector2Array()
var smoothed_polygon: PackedVector2Array = PackedVector2Array()
var post_simp_polygon: PackedVector2Array = PackedVector2Array()
var final_polygon: PackedVector2Array = PackedVector2Array()

# Track which stages need recomputation (dirty flags)
var dirty_stages: Dictionary = {
	"contour": true,           # Needs contour extraction
	"pre_simp": true,          # Needs pre-simplification
	"smooth": true,            # Needs smoothing
	"post_simp": true,         # Needs post-simplification
	"self_intersect": true     # Needs self-intersection resolution
}

# Section collapse states (all collapsed by default)
var section_states: Dictionary = {
	"contour": false,
	"pre_simp": false,
	"smooth": false,
	"post_simp": false,
	"mesh_settings": false
}

func _ready():
	if not _validate_ui_references():
		push_error("CutoutDock: Missing UI references. Please assign all required nodes in the Inspector.")
		push_error("CutoutDock: The dock will not function properly. Check the scene setup in cutout_dock.tscn")
		# Disable the dock to prevent further errors
		set_process(false)
		set_physics_process(false)
		return

	_setup_ui()
	_setup_algorithms()
	_setup_collapsible_sections()
	_connect_signals()


var _editor_interface: EditorInterface
var _environment_applied := false


## Called by the plugin to pass the EditorInterface
func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _apply_editor_environment() -> void:
	if _environment_applied or not _editor_interface:
		return

	if not preview_viewport_3d or not preview_viewport_3d.world_3d:
		return

	# Wait a frame to ensure the World3D scenario is fully initialized
	await get_tree().process_frame

	# Double-check viewport still exists after await
	if not preview_viewport_3d or not preview_viewport_3d.world_3d:
		return

	# Get the 3D editor's environment
	var editor_env := _get_editor_3d_environment(_editor_interface)

	if editor_env:
		# Duplicate the environment so we have our own copy
		editor_env = editor_env.duplicate()

		# Final safety check before setting
		if preview_viewport_3d.world_3d and preview_viewport_3d.world_3d.scenario.is_valid():
			preview_viewport_3d.world_3d.environment = editor_env
			_environment_applied = true


## Helper to get the 3D editor's environment
func _get_editor_3d_environment(editor_interface: EditorInterface) -> Environment:
	# Note: Accessing editor's default environment through settings is unreliable
	# across Godot versions, so we create a consistent fallback environment instead.
	# This ensures the 3D preview always has proper lighting regardless of editor state.

	# Create a basic default environment with sky lighting
	var default_env := Environment.new()
	default_env.background_mode = Environment.BG_SKY
	default_env.sky = Sky.new()
	default_env.sky.sky_material = ProceduralSkyMaterial.new()
	return default_env


## Recursively find nodes of a specific type
func _find_nodes_of_type(node: Node, type: String) -> Array[Node]:
	var result: Array[Node] = []

	if node.get_class() == type:
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_nodes_of_type(child, type))

	return result

# Mark a stage and all downstream stages as dirty
func _mark_dirty(stage: String):
	var stages_order = ["contour", "pre_simp", "smooth", "post_simp", "self_intersect"]
	var stage_index = stages_order.find(stage)

	if stage_index >= 0:
		for i in range(stage_index, stages_order.size()):
			dirty_stages[stages_order[i]] = true

func _validate_ui_references() -> bool:
	# Validate essential UI references are assigned
	var all_valid = true

	# Image section
	if not image_selector_button:
		push_warning("CutoutDock: image_selector_button not assigned")
		all_valid = false
	if not image_path_label:
		push_warning("CutoutDock: image_path_label not assigned")
		all_valid = false

	# Contour section
	if not contour_algorithm_option:
		push_warning("CutoutDock: contour_algorithm_option not assigned")
		all_valid = false
	if not contour_params:
		push_warning("CutoutDock: contour_params not assigned")
		all_valid = false

	# Algorithm sections
	if not pre_simp_algorithm_option:
		push_warning("CutoutDock: pre_simp_algorithm_option not assigned")
		all_valid = false
	if not pre_simp_params:
		push_warning("CutoutDock: pre_simp_params not assigned")
		all_valid = false

	if not smooth_algorithm_option:
		push_warning("CutoutDock: smooth_algorithm_option not assigned")
		all_valid = false
	if not smooth_params:
		push_warning("CutoutDock: smooth_params not assigned")
		all_valid = false

	if not post_simp_algorithm_option:
		push_warning("CutoutDock: post_simp_algorithm_option not assigned")
		all_valid = false
	if not post_simp_params:
		push_warning("CutoutDock: post_simp_params not assigned")
		all_valid = false

	# Preview section
	if not preview_tab_container:
		push_warning("CutoutDock: preview_tab_container not assigned")
		all_valid = false
	if not preview_container_2d:
		push_warning("CutoutDock: preview_container_2d not assigned")
		all_valid = false
	if not preview_viewport_2d:
		push_warning("CutoutDock: preview_viewport_2d not assigned")
		all_valid = false
	if not preview_camera_2d:
		push_warning("CutoutDock: preview_camera_2d not assigned")
		all_valid = false
	if not preview_container_3d:
		push_warning("CutoutDock: preview_container_3d not assigned")
		all_valid = false
	if not preview_viewport_3d:
		push_warning("CutoutDock: preview_viewport_3d not assigned")
		all_valid = false
	if not mesh_preview_3d:
		push_warning("CutoutDock: mesh_preview_3d not assigned")
		all_valid = false
	if not orbit_camera_3d:
		push_warning("CutoutDock: orbit_camera_3d not assigned")
		all_valid = false

	# Mesh settings
	if not mesh_settings_button:
		push_warning("CutoutDock: mesh_settings_button not assigned")
		all_valid = false
	if not mesh_settings_content:
		push_warning("CutoutDock: mesh_settings_content not assigned")
		all_valid = false
	if not depth_slider:
		push_warning("CutoutDock: depth_slider not assigned")
		all_valid = false
	if not depth_value:
		push_warning("CutoutDock: depth_value not assigned")
		all_valid = false
	if not mesh_width_spinbox:
		push_warning("CutoutDock: mesh_width_spinbox not assigned")
		all_valid = false
	if not mesh_height_spinbox:
		push_warning("CutoutDock: mesh_height_spinbox not assigned")
		all_valid = false

	# Export section
	if not export_button:
		push_warning("CutoutDock: export_button not assigned")
		all_valid = false

	return all_valid

func _setup_ui():
	# Discover algorithms from registry
	_contour_algorithms = CutoutAlgorithmRegistry.get_contour_algorithms()
	_polysimp_algorithms = CutoutAlgorithmRegistry.get_polysimp_algorithms()
	_smooth_algorithms = CutoutAlgorithmRegistry.get_smooth_algorithms()

	# Setup algorithm dropdowns dynamically
	if contour_algorithm_option:
		contour_algorithm_option.clear()
		for algo_info in _contour_algorithms:
			contour_algorithm_option.add_item(algo_info.display_name)
		if _contour_algorithms.size() > 0:
			contour_algorithm_option.selected = 0

	if pre_simp_algorithm_option:
		pre_simp_algorithm_option.clear()
		for algo_info in _polysimp_algorithms:
			pre_simp_algorithm_option.add_item(algo_info.display_name)
		if _polysimp_algorithms.size() > 0:
			pre_simp_algorithm_option.selected = 0

	if smooth_algorithm_option:
		smooth_algorithm_option.clear()
		for algo_info in _smooth_algorithms:
			smooth_algorithm_option.add_item(algo_info.display_name)
		if _smooth_algorithms.size() > 0:
			smooth_algorithm_option.selected = 0

	if post_simp_algorithm_option:
		post_simp_algorithm_option.clear()
		for algo_info in _polysimp_algorithms:
			post_simp_algorithm_option.add_item(algo_info.display_name)
		if _polysimp_algorithms.size() > 0:
			post_simp_algorithm_option.selected = 0

	# Setup mesh settings sliders
	if depth_slider:
		depth_slider.min_value = 0.01
		depth_slider.max_value = 1.0
		depth_slider.value = 0.1
		depth_slider.step = 0.01

	# Setup spinboxes
	if mesh_width_spinbox:
		mesh_width_spinbox.min_value = 0.1
		mesh_width_spinbox.max_value = 10.0
		mesh_width_spinbox.value = 1.0
		mesh_width_spinbox.step = 0.1

	if mesh_height_spinbox:
		mesh_height_spinbox.min_value = 0.1
		mesh_height_spinbox.max_value = 10.0
		mesh_height_spinbox.value = 1.0
		mesh_height_spinbox.step = 0.1

	# Update value labels
	_update_value_labels()

func _setup_algorithms():
	# Create default algorithms from discovered registry (first available)
	if _contour_algorithms.size() > 0:
		contour_algorithm = _contour_algorithms[0].create_instance()

	if _polysimp_algorithms.size() > 0:
		pre_simp_algorithm = _polysimp_algorithms[0].create_instance()
		post_simp_algorithm = _polysimp_algorithms[0].create_instance()

	if _smooth_algorithms.size() > 0:
		smooth_algorithm = _smooth_algorithms[0].create_instance()

	# Defer parameter UI initialization to ensure containers are ready
	call_deferred("_initialize_parameter_ui")

func _initialize_parameter_ui():
	# Initialize parameter UI for all algorithms - they're always visible now
	# Contour parameters
	if contour_params and contour_algorithm:
		_update_algorithm_params(contour_params, contour_algorithm)

	# Pre-simplification parameters
	if pre_simp_params and pre_simp_algorithm:
		_update_algorithm_params(pre_simp_params, pre_simp_algorithm)

	# Smoothing parameters
	if smooth_params and smooth_algorithm:
		_update_algorithm_params(smooth_params, smooth_algorithm)

	# Post-simplification parameters
	if post_simp_params and post_simp_algorithm:
		_update_algorithm_params(post_simp_params, post_simp_algorithm)

func _setup_collapsible_sections():
	# Setup contour section
	if contour_section_button:
		_style_section_button(contour_section_button, "▶ Contour Extraction", section_states["contour"])
		contour_section_button.pressed.connect(func(): _toggle_section("contour"))
	if contour_section_content:
		contour_section_content.visible = section_states["contour"]
		_ensure_section_structure(contour_section_content, "contour")

	# Setup pre-simplification section
	if pre_simp_section_button:
		_style_section_button(pre_simp_section_button, "▶ Pre-Simplification", section_states["pre_simp"])
		pre_simp_section_button.pressed.connect(func(): _toggle_section("pre_simp"))
	if pre_simp_section_content:
		pre_simp_section_content.visible = section_states["pre_simp"]
		_ensure_section_structure(pre_simp_section_content, "pre_simp")

	# Setup smoothing section
	if smooth_section_button:
		_style_section_button(smooth_section_button, "▶ Smoothing", section_states["smooth"])
		smooth_section_button.pressed.connect(func(): _toggle_section("smooth"))
	if smooth_section_content:
		smooth_section_content.visible = section_states["smooth"]
		_ensure_section_structure(smooth_section_content, "smooth")

	# Setup post-simplification section
	if post_simp_section_button:
		_style_section_button(post_simp_section_button, "▶ Post-Simplification", section_states["post_simp"])
		post_simp_section_button.pressed.connect(func(): _toggle_section("post_simp"))
	if post_simp_section_content:
		post_simp_section_content.visible = section_states["post_simp"]
		_ensure_section_structure(post_simp_section_content, "post_simp")

	# Setup mesh settings section
	if mesh_settings_button:
		_style_section_button(mesh_settings_button, "▶ Mesh Settings", section_states["mesh_settings"])
		mesh_settings_button.pressed.connect(func(): _toggle_section("mesh_settings"))
	if mesh_settings_content:
		mesh_settings_content.visible = section_states["mesh_settings"]
		_ensure_section_structure(mesh_settings_content, "mesh_settings")

func _style_section_button(button: Button, text: String, is_expanded: bool):
	button.text = text
	button.flat = false
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Add visual styling to make it look like a header
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)

func _ensure_section_structure(content_container: VBoxContainer, section_type: String):
	# Add spacing between elements
	content_container.add_theme_constant_override("separation", 8)

	# Add padding to content container for better visual hierarchy
	if content_container.has_theme_constant_override("margin_left"):
		content_container.add_theme_constant_override("margin_left", 20)
	else:
		# If the container doesn't support margins directly, we can add it to children
		for child in content_container.get_children():
			if child is Control:
				child.set("theme_override_constants/margin_left", 20)

func _toggle_section(section_name: String):
	section_states[section_name] = not section_states[section_name]
	var is_expanded = section_states[section_name]
	var arrow = "▼ " if is_expanded else "▶ "

	match section_name:
		"contour":
			if contour_section_button:
				contour_section_button.text = arrow + "Contour Extraction"
				contour_section_button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)
			if contour_section_content:
				contour_section_content.visible = is_expanded
		"pre_simp":
			if pre_simp_section_button:
				pre_simp_section_button.text = arrow + "Pre-Simplification"
				pre_simp_section_button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)
			if pre_simp_section_content:
				pre_simp_section_content.visible = is_expanded
		"smooth":
			if smooth_section_button:
				smooth_section_button.text = arrow + "Smoothing"
				smooth_section_button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)
			if smooth_section_content:
				smooth_section_content.visible = is_expanded
		"post_simp":
			if post_simp_section_button:
				post_simp_section_button.text = arrow + "Post-Simplification"
				post_simp_section_button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)
			if post_simp_section_content:
				post_simp_section_content.visible = is_expanded
		"mesh_settings":
			if mesh_settings_button:
				mesh_settings_button.text = arrow + "Mesh Settings"
				mesh_settings_button.modulate = Color(0.95, 0.95, 0.95) if is_expanded else Color(0.85, 0.85, 0.85)
			if mesh_settings_content:
				mesh_settings_content.visible = is_expanded

func _connect_signals():
	# Connect UI signals
	if image_selector_button:
		image_selector_button.pressed.connect(_on_image_selector_pressed)

	if contour_algorithm_option:
		contour_algorithm_option.item_selected.connect(_on_contour_algorithm_changed)

	# Checkboxes removed - algorithms are now mandatory
	if pre_simp_algorithm_option:
		pre_simp_algorithm_option.item_selected.connect(_on_pre_simp_algorithm_changed)

	# Checkboxes removed - algorithms are now mandatory
	if smooth_algorithm_option:
		smooth_algorithm_option.item_selected.connect(_on_smooth_algorithm_changed)

	# Checkboxes removed - algorithms are now mandatory
	if post_simp_algorithm_option:
		post_simp_algorithm_option.item_selected.connect(_on_post_simp_algorithm_changed)

	if depth_slider:
		depth_slider.value_changed.connect(_on_depth_changed)

	if mesh_width_spinbox:
		mesh_width_spinbox.value_changed.connect(_on_mesh_size_changed)
	if mesh_height_spinbox:
		mesh_height_spinbox.value_changed.connect(_on_mesh_size_changed)

	if export_button:
		export_button.pressed.connect(_on_export_pressed)
		# Make export button more prominent
		export_button.add_theme_font_size_override("font_size", 14)
		export_button.custom_minimum_size.y = 35

	# Connect algorithm changed signals
	if contour_algorithm:
		contour_algorithm.changed.connect(func(): _mark_dirty("contour"); _run_pipeline())
	if pre_simp_algorithm:
		pre_simp_algorithm.changed.connect(func(): _mark_dirty("pre_simp"); _run_pipeline())
	if smooth_algorithm:
		smooth_algorithm.changed.connect(func(): _mark_dirty("smooth"); _run_pipeline())
	if post_simp_algorithm:
		post_simp_algorithm.changed.connect(func(): _mark_dirty("post_simp"); _run_pipeline())

	# Connect SubViewportContainer gui_input signals to camera handlers
	if preview_container_2d and preview_camera_2d:
		preview_container_2d.gui_input.connect(_on_preview_2d_gui_input)
	if preview_container_3d and orbit_camera_3d:
		preview_container_3d.gui_input.connect(_on_preview_3d_gui_input)

	# Connect tab change to apply editor environment when switching to 3D preview
	if preview_tab_container:
		preview_tab_container.tab_changed.connect(_on_preview_tab_changed)

func _on_image_selector_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png", "PNG Image")
	file_dialog.add_filter("*.jpg,*.jpeg", "JPEG Image")
	file_dialog.add_filter("*.webp", "WebP Image")
	file_dialog.add_filter("*.svg", "SVG Image")
	file_dialog.add_filter("*.exr", "EXR Image")
	file_dialog.current_dir = "res://"
	file_dialog.access = FileDialog.ACCESS_RESOURCES

	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

	await file_dialog.file_selected
	var path = file_dialog.current_path
	file_dialog.queue_free()

	_load_image(path)

func _load_image(path: String):
	current_texture = load(path)
	if current_texture:
		current_image = current_texture.get_image()
		if image_path_label:
			image_path_label.text = path.get_file()

		# Calculate and set mesh size based on aspect ratio
		if current_image and mesh_width_spinbox and mesh_height_spinbox:
			var img_width: float = current_image.get_width()
			var img_height: float = current_image.get_height()
			if img_width > 0:
				var aspect_ratio: float = img_height / img_width
				mesh_width_spinbox.value = 1.0
				mesh_height_spinbox.value = aspect_ratio

		# Update preview
		if polygon_preview:
			polygon_preview.set_texture(current_texture)

		# Fit camera to image
		_fit_camera_to_image()

		# Mark entire pipeline as dirty (new image requires full reprocessing)
		_mark_dirty("contour")
		# Run pipeline
		_run_pipeline()

func _fit_camera_to_image():
	if not current_texture or not preview_camera_2d:
		return

	var image_size := current_texture.get_size()
	var image_rect := Rect2(Vector2.ZERO, image_size)
	preview_camera_2d.fit_to_rect(image_rect, 0.9)

func _run_pipeline():
	if not current_image:
		return

	var polygon: PackedVector2Array

	# Stage 1: Contour extraction
	if dirty_stages["contour"]:
		var polygons = contour_algorithm.calculate_boundary(current_image)
		if polygons.is_empty():
			return
		contour_polygon = polygons[0]  # Use first polygon
		dirty_stages["contour"] = false
		polygon = contour_polygon
	else:
		polygon = contour_polygon
	print("polygon after contour", polygon)

	# Stage 2: Pre-simplification (mandatory)
	if dirty_stages["pre_simp"]:
		if pre_simp_algorithm:
			pre_simp_polygon = pre_simp_algorithm.simplify(polygon)
		else:
			pre_simp_polygon = polygon
		dirty_stages["pre_simp"] = false
		polygon = pre_simp_polygon
	else:
		polygon = pre_simp_polygon

	# Stage 3: Smoothing (mandatory)
	if dirty_stages["smooth"]:
		if smooth_algorithm:
			smoothed_polygon = smooth_algorithm.smooth(polygon)
		else:
			smoothed_polygon = polygon
		dirty_stages["smooth"] = false
		polygon = smoothed_polygon
	else:
		polygon = smoothed_polygon

	# Stage 4: Post-simplification (mandatory)
	if dirty_stages["post_simp"]:
		if post_simp_algorithm:
			post_simp_polygon = post_simp_algorithm.simplify(polygon)
		else:
			post_simp_polygon = polygon
		dirty_stages["post_simp"] = false
		polygon = post_simp_polygon
	else:
		polygon = post_simp_polygon

	# Stage 5: Self-intersection resolution
	if dirty_stages["self_intersect"]:
		polygon = _resolve_self_intersections(polygon)
		final_polygon = polygon
		dirty_stages["self_intersect"] = false
	else:
		final_polygon = polygon

	# Update 2D preview
	if polygon_preview:
		polygon_preview.set_polygon(polygon)

	# Update 3D preview
	_update_3d_preview()

func _update_3d_preview() -> void:
	if not mesh_preview_3d or not current_texture or final_polygon.is_empty():
		if mesh_preview_3d:
			mesh_preview_3d.clear()
		return

	# Create or update the preview CutoutMesh
	if not _preview_cutout_mesh:
		_preview_cutout_mesh = CutoutMesh.new()

	_preview_cutout_mesh.texture = current_texture
	_preview_cutout_mesh.mask.assign([final_polygon])
	_preview_cutout_mesh.depth = depth_slider.value if depth_slider else 0.1
	_preview_cutout_mesh.mesh_size = Vector2(
		mesh_width_spinbox.value if mesh_width_spinbox else 1.0,
		mesh_height_spinbox.value if mesh_height_spinbox else 1.0
	)

	# Assign to the 3D preview
	mesh_preview_3d.set_cutout_mesh(_preview_cutout_mesh)

	# Fit the orbit camera to the mesh
	_fit_3d_camera()


func _fit_3d_camera() -> void:
	if not orbit_camera_3d or not mesh_preview_3d or not _preview_cutout_mesh:
		return

	var bounds := mesh_preview_3d.get_mesh_bounds()
	var center := mesh_preview_3d.get_mesh_center()
	orbit_camera_3d.fit_to_bounds(bounds.size, center)


func _on_contour_algorithm_changed(index: int):
	if index < 0 or index >= _contour_algorithms.size():
		return

	contour_algorithm = _contour_algorithms[index].create_instance()
	if not contour_algorithm:
		return

	contour_algorithm.changed.connect(func(): _mark_dirty("contour"); _run_pipeline())
	_update_algorithm_params(contour_params, contour_algorithm)
	_mark_dirty("contour")
	_run_pipeline()

# Pre-simplification toggle removed - always enabled

func _on_pre_simp_algorithm_changed(index: int):
	if index < 0 or index >= _polysimp_algorithms.size():
		return

	pre_simp_algorithm = _polysimp_algorithms[index].create_instance()
	if not pre_simp_algorithm:
		return

	pre_simp_algorithm.changed.connect(func(): _mark_dirty("pre_simp"); _run_pipeline())
	_update_algorithm_params(pre_simp_params, pre_simp_algorithm)
	_mark_dirty("pre_simp")
	_run_pipeline()

# Smoothing toggle removed - always enabled

func _on_smooth_algorithm_changed(index: int):
	if index < 0 or index >= _smooth_algorithms.size():
		return

	smooth_algorithm = _smooth_algorithms[index].create_instance()
	if not smooth_algorithm:
		return

	smooth_algorithm.changed.connect(func(): _mark_dirty("smooth"); _run_pipeline())
	_update_algorithm_params(smooth_params, smooth_algorithm)
	_mark_dirty("smooth")
	_run_pipeline()

# Post-simplification toggle removed - always enabled

func _on_post_simp_algorithm_changed(index: int):
	if index < 0 or index >= _polysimp_algorithms.size():
		return

	post_simp_algorithm = _polysimp_algorithms[index].create_instance()
	if not post_simp_algorithm:
		return

	post_simp_algorithm.changed.connect(func(): _mark_dirty("post_simp"); _run_pipeline())
	_update_algorithm_params(post_simp_params, post_simp_algorithm)
	_mark_dirty("post_simp")
	_run_pipeline()

func _update_algorithm_params(container: VBoxContainer, algorithm: Resource):
	if not container:
		return

	# Clear existing parameter controls
	for child in container.get_children():
		child.queue_free()

	# Create new parameter controls based on algorithm properties
	var properties = algorithm.get_property_list()
	for prop in properties:
		# Skip non-exported and built-in Resource properties
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if prop.name in ["resource_local_to_scene", "resource_path", "resource_name", "script", "resource_scene_unique_id"]:
			continue

		if prop.type == TYPE_FLOAT:
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = prop.name.replace("_", " ").capitalize() + ":"
			label.custom_minimum_size.x = 120
			hbox.add_child(label)

			# Try to get hints from property if available
			var min_val = 0.0
			var max_val = 10.0
			var step_val = 0.01
			var is_exponential = false

			# Check for property hints (like @export_range)
			if prop.has("hint_string") and prop.hint_string != "":
				var parts = prop.hint_string.split(",")
				if parts.size() >= 2:
					min_val = float(parts[0])
					max_val = float(parts[1])
				if parts.size() >= 3:
					step_val = float(parts[2])
				# Check for exponential flag
				if parts.size() >= 4 and parts[3].strip_edges() == "\"exp\"":
					is_exponential = true

			var slider = HSlider.new()
			slider.min_value = min_val
			slider.max_value = max_val
			slider.value = algorithm.get(prop.name)
			slider.step = step_val
			slider.custom_minimum_size.x = 150

			# Use exponential editing for certain parameters or when hint specifies
			var exponential_params = ["epsilon", "area_threshold", "expansion_radius", "density_threshold"]
			if prop.name in exponential_params or is_exponential:
				slider.exp_edit = true
				# Ensure min value is not 0 for exponential sliders
				if slider.min_value == 0.0:
					slider.min_value = 0.001

			hbox.add_child(slider)

			var value_label = Label.new()
			value_label.custom_minimum_size.x = 50

			# Update label with appropriate precision
			var update_label = func(val):
				if val < 0.01:
					value_label.text = "%.4f" % val
				elif val < 0.1:
					value_label.text = "%.3f" % val
				elif val < 10.0:
					value_label.text = "%.2f" % val
				else:
					value_label.text = "%.1f" % val

			update_label.call(slider.value)
			hbox.add_child(value_label)

			slider.value_changed.connect(func(val):
				algorithm.set(prop.name, val)
				update_label.call(val)
			)

			container.add_child(hbox)

		elif prop.type == TYPE_INT:
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = prop.name.replace("_", " ").capitalize() + ":"
			label.custom_minimum_size.x = 120
			hbox.add_child(label)

			var spinbox = SpinBox.new()
			var min_val = 1
			var max_val = 10

			# Check for property hints
			if prop.has("hint_string") and prop.hint_string != "":
				var parts = prop.hint_string.split(",")
				if parts.size() >= 2:
					min_val = int(parts[0])
					max_val = int(parts[1])

			spinbox.min_value = min_val
			spinbox.max_value = max_val
			spinbox.value = algorithm.get(prop.name)
			spinbox.step = 1
			hbox.add_child(spinbox)

			spinbox.value_changed.connect(func(val):
				algorithm.set(prop.name, int(val))
			)

			container.add_child(hbox)

		elif prop.type == TYPE_BOOL:
			var hbox = HBoxContainer.new()
			var checkbox = CheckBox.new()
			checkbox.text = prop.name.replace("_", " ").capitalize()
			checkbox.button_pressed = algorithm.get(prop.name)
			hbox.add_child(checkbox)

			checkbox.toggled.connect(func(pressed):
				algorithm.set(prop.name, pressed)
			)

			container.add_child(hbox)

func _on_depth_changed(value: float):
	_update_value_labels()
	_update_3d_preview()

func _on_mesh_size_changed(_value: float):
	_update_3d_preview()

func _update_value_labels():
	if depth_value and depth_slider:
		depth_value.text = "%.2f" % depth_slider.value

func _on_export_pressed():
	if not current_texture or final_polygon.is_empty():
		push_error("No image loaded or polygon not generated")
		return

	# Create CutoutMesh
	var cutout_mesh = CutoutMesh.new()
	cutout_mesh.texture = current_texture
	cutout_mesh.mask.assign([final_polygon])  # Wrap in array
	cutout_mesh.depth = depth_slider.value if depth_slider else 0.1
	cutout_mesh.mesh_size = Vector2(
		mesh_width_spinbox.value if mesh_width_spinbox else 1.0,
		mesh_height_spinbox.value if mesh_height_spinbox else 1.0
	)

	# Generate mesh
	cutout_mesh.generate_mesh()

	# Always show file dialog for saving
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.tres", "Godot Resource (Text)")
	file_dialog.add_filter("*.res", "Godot Resource (Binary)")
	file_dialog.current_dir = "res://"

	# Use image name as default filename if available
	if image_path_label and image_path_label.text != "No image selected":
		var base_name = image_path_label.text.get_basename()
		file_dialog.current_file = base_name + "_cutout.tres"
	else:
		file_dialog.current_file = "cutout_mesh.tres"

	file_dialog.access = FileDialog.ACCESS_RESOURCES

	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

	# Wait for file selection or cancel
	file_dialog.file_selected.connect(func(path):
		var save_path = path

		# Update the path display if we have a path line
		if export_path_line:
			export_path_line.text = save_path
			export_path_line.tooltip_text = save_path

		# Save the resource with explicit flags to ensure overwriting works
		var error = ResourceSaver.save(cutout_mesh, save_path, ResourceSaver.FLAG_CHANGE_PATH)
		if error == OK:
			print("CutoutMesh saved to: ", save_path)
			cutout_mesh_created.emit(cutout_mesh)

			# Show success feedback
			if export_path_line:
				export_path_line.modulate = Color(0.5, 1.0, 0.5)  # Green tint
				await get_tree().create_timer(0.5).timeout
				export_path_line.modulate = Color.WHITE
		else:
			push_error("Failed to save CutoutMesh: " + str(error))

		file_dialog.queue_free()
	)

	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

# Allow drag and drop of images
func _can_drop_data(_position: Vector2, data) -> bool:
	if data is Dictionary and data.has("files"):
		var files = data["files"]
		if files.size() == 1:
			var file = files[0]
			var extension = file.get_extension().to_lower()
			return extension in ["png", "jpg", "jpeg", "webp", "svg", "exr"]
	return false

func _drop_data(_position: Vector2, data):
	if data is Dictionary and data.has("files"):
		var files = data["files"]
		if files.size() > 0:
			_load_image(files[0])

func _resolve_self_intersections(polygon: PackedVector2Array) -> PackedVector2Array:
	# Use Godot's Geometry2D to merge polygons and resolve self-intersections
	var merged_polygons = Geometry2D.merge_polygons(polygon, polygon)
	if merged_polygons.size() > 0:
		return merged_polygons[0]
	return polygon


## Forward 2D preview input to the pan/zoom camera
func _on_preview_2d_gui_input(event: InputEvent) -> void:
	if preview_camera_2d:
		preview_camera_2d.handle_input(event)


## Forward 3D preview input to the orbit camera
func _on_preview_3d_gui_input(event: InputEvent) -> void:
	if orbit_camera_3d:
		orbit_camera_3d.handle_input(event)


## Called when preview tab changes - apply editor environment when switching to 3D
func _on_preview_tab_changed(tab: int) -> void:
	if tab == 1:  # 3D preview tab
		_apply_editor_environment()
