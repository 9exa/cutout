extends Node3D

## Interactive debug scene for CutoutMeshInstance3D and CutoutMesh
## Provides UI controls to tweak properties and debug information display

# Scene nodes
@onready var cutout_instance: Node3D = $CutoutMeshInstance3D
@onready var camera: Camera3D = $Camera3D

# UI Controls - CutoutMesh Properties
@onready var texture_path_edit: LineEdit = %TexturePath
@onready var browse_texture_btn: Button = %BrowseTextureButton
@onready var file_dialog: FileDialog = %FileDialog
@onready var alpha_threshold_slider: HSlider = %AlphaThresholdSlider
@onready var alpha_threshold_label: Label = %AlphaThresholdLabel
@onready var detail_threshold_slider: HSlider = %DetailThresholdSlider
@onready var detail_threshold_label: Label = %DetailThresholdLabel
@onready var depth_slider: HSlider = %DepthSlider
@onready var depth_label: Label = %DepthLabel
@onready var mesh_size_slider: HSlider = %MeshSizeSlider
@onready var mesh_size_label: Label = %MeshSizeLabel
@onready var extrusion_scale_slider: HSlider = %ExtrusionScaleSlider
@onready var extrusion_scale_label: Label = %ExtrusionScaleLabel

# UI Controls - Instance Management
@onready var create_from_texture_btn: Button = %CreateFromTextureButton
@onready var save_cutout_mesh_btn: Button = %SaveCutoutMeshButton
@onready var save_file_dialog: FileDialog = %SaveFileDialog
@onready var spawn_instance_btn: Button = %SpawnInstanceButton
@onready var clear_instances_btn: Button = %ClearInstancesButton
@onready var toggle_sharing_btn: Button = %ToggleSharingButton

# UI Controls - Debug Info
@onready var debug_info_label: RichTextLabel = %DebugInfoLabel

# State
var current_cutout_mesh: Resource = null
var spawned_instances: Array[Node3D] = []
var use_shared_resource: bool = true

func _ready():
	# Connect UI signals
	browse_texture_btn.pressed.connect(_on_browse_texture_pressed)
	file_dialog.file_selected.connect(_on_texture_file_selected)
	create_from_texture_btn.pressed.connect(_on_create_from_texture_pressed)
	save_cutout_mesh_btn.pressed.connect(_on_save_cutout_mesh_pressed)
	save_file_dialog.file_selected.connect(_on_save_file_selected)
	spawn_instance_btn.pressed.connect(_on_spawn_instance_pressed)
	clear_instances_btn.pressed.connect(_on_clear_instances_pressed)
	toggle_sharing_btn.pressed.connect(_on_toggle_sharing_pressed)

	alpha_threshold_slider.value_changed.connect(_on_alpha_threshold_changed)
	detail_threshold_slider.value_changed.connect(_on_detail_threshold_changed)
	depth_slider.value_changed.connect(_on_depth_changed)
	mesh_size_slider.value_changed.connect(_on_mesh_size_changed)
	extrusion_scale_slider.value_changed.connect(_on_extrusion_scale_changed)

	# Initialize labels
	_update_slider_labels()
	_update_debug_info()

	# Update toggle button text
	_update_toggle_button_text()

func _update_slider_labels():
	alpha_threshold_label.text = "Alpha Threshold: %.2f" % alpha_threshold_slider.value
	detail_threshold_label.text = "Detail Threshold: %.1f" % detail_threshold_slider.value
	depth_label.text = "Depth: %.2f" % depth_slider.value
	mesh_size_label.text = "Mesh Size: %.2f" % mesh_size_slider.value
	extrusion_scale_label.text = "Extrusion Scale: %.2f" % extrusion_scale_slider.value

func _update_toggle_button_text():
	if use_shared_resource:
		toggle_sharing_btn.text = "Mode: Shared Resource"
	else:
		toggle_sharing_btn.text = "Mode: Unique Resources"

func _on_browse_texture_pressed():
	file_dialog.popup_centered()

func _on_texture_file_selected(path: String):
	texture_path_edit.text = path
	print("Selected texture: ", path)

func _on_create_from_texture_pressed():
	var path = texture_path_edit.text
	if path.is_empty():
		print("Error: No texture path specified")
		return

	var texture = load(path)
	if texture == null:
		print("Error: Failed to load texture from: ", path)
		return

	print("Creating CutoutMesh from texture...")

	# Load the CutoutMesh class
	var CutoutMesh = load("res://addons/cutout/resources/cutout_mesh.gd")

	# Create mesh with current settings
	current_cutout_mesh = CutoutMesh.create_from_texture(
		texture,
		alpha_threshold_slider.value,
		detail_threshold_slider.value
	)

	if current_cutout_mesh == null:
		print("Error: Failed to create CutoutMesh")
		return

	# Apply current property values
	current_cutout_mesh.depth = depth_slider.value
	current_cutout_mesh.mesh_size = Vector2(mesh_size_slider.value, mesh_size_slider.value)
	current_cutout_mesh.extrusion_texture_scale = extrusion_scale_slider.value

	# Assign to instance
	cutout_instance.cutout_mesh = current_cutout_mesh

	print("CutoutMesh created and assigned successfully!")
	_update_debug_info()

func _on_save_cutout_mesh_pressed():
	if current_cutout_mesh == null:
		print("Error: No CutoutMesh to save. Create one first!")
		return

	save_file_dialog.popup_centered()

func _on_save_file_selected(path: String):
	if current_cutout_mesh == null:
		print("Error: No CutoutMesh to save")
		return

	# Ensure the path has .tres extension
	if not path.ends_with(".tres"):
		path += ".tres"

	var err = ResourceSaver.save(current_cutout_mesh, path)
	if err == OK:
		print("CutoutMesh saved successfully to: ", path)
	else:
		print("Error saving CutoutMesh: ", err)

func _on_spawn_instance_pressed():
	if current_cutout_mesh == null:
		print("Error: No CutoutMesh to spawn. Create one first!")
		return

	# Load the CutoutMeshInstance3D class
	var CutoutMeshInstance3D = load("res://addons/cutout/nodes/cutout_mesh_instance_3d.gd")

	# Create new instance
	var new_instance = Node3D.new()
	new_instance.set_script(CutoutMeshInstance3D)

	# Assign resource (shared or unique)
	if use_shared_resource:
		new_instance.cutout_mesh = current_cutout_mesh
		print("Spawned instance with SHARED resource")
	else:
		# Duplicate the resource for unique copy
		new_instance.cutout_mesh = current_cutout_mesh.duplicate()
		print("Spawned instance with UNIQUE resource")

	# Position in a circle around the main instance
	var angle = spawned_instances.size() * (PI * 2.0 / 8.0)  # 8 positions max
	var radius = 3.0
	new_instance.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)

	# Add to scene
	add_child(new_instance)
	spawned_instances.append(new_instance)

	_update_debug_info()

func _on_clear_instances_pressed():
	for instance in spawned_instances:
		instance.queue_free()
	spawned_instances.clear()
	print("Cleared all spawned instances")
	_update_debug_info()

func _on_toggle_sharing_pressed():
	use_shared_resource = !use_shared_resource
	_update_toggle_button_text()
	print("Resource sharing mode: ", "SHARED" if use_shared_resource else "UNIQUE")

# Property change handlers
func _on_alpha_threshold_changed(value: float):
	alpha_threshold_label.text = "Alpha Threshold: %.2f" % value
	# Note: Requires recreating mesh from texture

func _on_detail_threshold_changed(value: float):
	detail_threshold_label.text = "Detail Threshold: %.1f" % value
	# Note: Requires recreating mesh from texture

func _on_depth_changed(value: float):
	depth_label.text = "Depth: %.2f" % value
	if current_cutout_mesh != null:
		current_cutout_mesh.depth = value
		_update_debug_info()

func _on_mesh_size_changed(value: float):
	mesh_size_label.text = "Mesh Size: %.2f" % value
	if current_cutout_mesh != null:
		current_cutout_mesh.mesh_size = Vector2(value, value)
		_update_debug_info()

func _on_extrusion_scale_changed(value: float):
	extrusion_scale_label.text = "Extrusion Scale: %.2f" % value
	if current_cutout_mesh != null:
		current_cutout_mesh.extrusion_texture_scale = value
		_update_debug_info()

func _update_debug_info():
	var info = "[b]Debug Information[/b]\n\n"

	# CutoutMesh info
	if current_cutout_mesh != null:
		info += "[b]CutoutMesh:[/b]\n"

		var mesh = current_cutout_mesh.get_mesh()
		if mesh != null:
			var vertex_count = 0
			var triangle_count = 0
			var surface_count = mesh.get_surface_count()

			for i in range(surface_count):
				var arrays = mesh.surface_get_arrays(i)
				if arrays.size() > 0 and arrays[Mesh.ARRAY_VERTEX] != null:
					var verts = arrays[Mesh.ARRAY_VERTEX]
					vertex_count += verts.size()

					# Estimate triangles
					if arrays[Mesh.ARRAY_INDEX] != null:
						var indices = arrays[Mesh.ARRAY_INDEX]
						triangle_count += indices.size() / 3
					else:
						triangle_count += verts.size() / 3

			info += "  Vertices: %d\n" % vertex_count
			info += "  Triangles: %d\n" % triangle_count
			info += "  Surfaces: %d\n" % surface_count
		else:
			info += "  [color=red]Mesh not generated[/color]\n"

		info += "  Depth: %.2f\n" % current_cutout_mesh.depth
		info += "  Mesh Size: (%.2f, %.2f)\n" % [current_cutout_mesh.mesh_size.x, current_cutout_mesh.mesh_size.y]

		var mask_count = current_cutout_mesh.mask.size() if current_cutout_mesh.mask != null else 0
		info += "  Mask polygons: %d\n" % mask_count
	else:
		info += "[color=yellow]No CutoutMesh created yet[/color]\n"

	info += "\n"

	# Instance info
	info += "[b]Instances:[/b]\n"
	info += "  Main instance: 1\n"
	info += "  Spawned instances: %d\n" % spawned_instances.size()
	info += "  Total instances: %d\n" % (1 + spawned_instances.size())

	if current_cutout_mesh != null:
		# Count how many instances share the resource
		var shared_count = 1  # Main instance
		for instance in spawned_instances:
			if instance.cutout_mesh == current_cutout_mesh:
				shared_count += 1

		info += "  Sharing main resource: %d\n" % shared_count

		if shared_count > 1:
			info += "  [color=green]Resource sharing active![/color]\n"

	info += "\n"

	# Memory efficiency note
	if spawned_instances.size() > 0 and use_shared_resource:
		info += "[b]Performance:[/b]\n"
		info += "[color=green]Using shared resource = efficient memory usage[/color]\n"
	elif spawned_instances.size() > 0 and !use_shared_resource:
		info += "[b]Performance:[/b]\n"
		info += "[color=yellow]Using unique resources = higher memory usage[/color]\n"

	debug_info_label.text = info

func _process(_delta):
	# Rotate camera around the scene
	if Input.is_action_pressed("ui_right"):
		camera.rotation.y -= 0.5 * _delta
	if Input.is_action_pressed("ui_left"):
		camera.rotation.y += 0.5 * _delta
	if Input.is_action_pressed("ui_up"):
		camera.position.y += 2.0 * _delta
	if Input.is_action_pressed("ui_down"):
		camera.position.y -= 2.0 * _delta
