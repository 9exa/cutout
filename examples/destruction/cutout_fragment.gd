extends RigidBody3D

## Individual fragment behavior for destroyed CutoutMesh pieces
## Handles physics, collision, and cleanup

# Fragment settings
var cutout_mesh_instance: CutoutMeshInstance3D
var lifetime: float = 10.0
var fade_duration: float = 2.0
var use_convex_collision: bool = false

# Fade state
var is_fading: bool = false
var fade_timer: float = 0.0
var initial_transparency: float = 1.0

# Signals
signal fragment_expired


func _ready() -> void:
	# Set up as a physics object
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = false

	# Enable continuous collision detection for fast-moving fragments
	continuous_cd = true

	# Start lifetime timer
	if lifetime > 0:
		start_lifetime_timer()


func setup(
	cutout_mesh: CutoutMesh,
	initial_position: Vector3,
	initial_rotation: Vector3,
	explosion_force: float,
	rotation_force: float,
	lifetime_seconds: float,
	fade_seconds: float
) -> void:
	if cutout_mesh == null or cutout_mesh.mask.is_empty():
		push_warning("Fragment: No cutout mesh provided for setup")
		return
	# Store settings
	lifetime = lifetime_seconds
	fade_duration = fade_seconds

	var fragment_center: Vector2 = calculate_polygon_centroid(cutout_mesh.mask[0])
	var fragment_offset := Vector3(fragment_center.x, fragment_center.y, 0)
	print("fragment_offset: ", fragment_offset)

	# Create visual mesh instance
	cutout_mesh_instance = CutoutMeshInstance3D.new()
	cutout_mesh_instance.position = -fragment_offset
	cutout_mesh_instance.cutout_mesh = cutout_mesh
	cutout_mesh_instance.name = "FragmentMesh"
	add_child(cutout_mesh_instance)

	global_position = initial_position
	global_rotation = initial_rotation

	position += fragment_offset

	# Since we positioned the RigidBody at the centroid, set center_of_mass to origin
	center_of_mass = Vector3.ZERO

	# Generate collision shape from mesh
	create_collision_shape(fragment_offset)


func create_collision_shape(offset: Vector3) -> void:
	if not cutout_mesh_instance or not cutout_mesh_instance.cutout_mesh:
		return

	# Wait for mesh to be generated
	await get_tree().process_frame

	# Get the internal MeshInstance3D
	var mesh_instance: MeshInstance3D = cutout_mesh_instance.get_mesh_instance()
	if not mesh_instance or not mesh_instance.mesh:
		push_warning("Fragment: Could not find mesh for collision shape")
		return

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	collision_shape.position = -offset

	if use_convex_collision:
		# Create convex collision (faster but less accurate)
		var shape := mesh_instance.mesh.create_convex_shape()
		var points := shape.get_points()
		for i in range(len(points)):
			points[i] -= offset
		# shape.set_points(points)

		collision_shape.shape = shape
	else:
		# Create trimesh collision (slower but more accurate)
		var shape := mesh_instance.mesh.create_trimesh_shape()
		var faces := shape.get_faces()
		for i in range(len(faces)):
			faces[i] -= offset
		# shape.set_faces(faces)

		collision_shape.shape = shape

	add_child(collision_shape)


func apply_explosion_force(direction: Vector3, force: float, torque: float) -> void:
	# Apply central impulse
	apply_central_impulse(direction * force)

	# Apply random torque for rotation
	var random_torque := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * torque

	apply_torque_impulse(random_torque)


func start_lifetime_timer() -> void:
	# Wait for lifetime minus fade duration
	var wait_time: float = max(0.0, lifetime - fade_duration)

	if wait_time > 0:
		await get_tree().create_timer(wait_time).timeout

	# Start fading
	start_fade_out()


func start_fade_out() -> void:
	is_fading = true
	fade_timer = 0.0

	# Store initial transparency
	if cutout_mesh_instance:
		var mesh_inst := cutout_mesh_instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst and mesh_inst.material_override:
			var mat := mesh_inst.material_override
			if mat.has_property("albedo_color"):
				initial_transparency = mat.albedo_color.a


func _physics_process(delta: float) -> void:
	if is_fading:
		process_fade(delta)

	# Optional: Apply drag to slow down over time
	if linear_velocity.length() > 0.1:
		linear_velocity *= 0.99

	if angular_velocity.length() > 0.1:
		angular_velocity *= 0.98


func process_fade(delta: float) -> void:
	fade_timer += delta

	if fade_timer >= fade_duration:
		# Finished fading, remove fragment
		expire()
		return

	# Calculate fade progress
	var fade_progress := fade_timer / fade_duration
	var alpha := 1.0 - fade_progress

	# Apply fade to mesh
	apply_transparency(alpha)


func apply_transparency(alpha: float) -> void:
	if not cutout_mesh_instance:
		return

	var mesh_inst := cutout_mesh_instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		return

	# Get or create material override
	if not mesh_inst.material_override:
		# Get base material from mesh
		if mesh_inst.mesh and mesh_inst.mesh.surface_get_material(0):
			mesh_inst.material_override = mesh_inst.mesh.surface_get_material(0).duplicate()
		else:
			# Create a basic material
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.WHITE
			mesh_inst.material_override = mat

	# Set transparency
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha * initial_transparency

		# Also handle face material if it exists
		if cutout_mesh_instance.face_material:
			var face_mat := cutout_mesh_instance.face_material as StandardMaterial3D
			if face_mat:
				face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				face_mat.albedo_color.a = alpha


func expire() -> void:
	fragment_expired.emit()
	queue_free()


func force_cleanup() -> void:
	# Immediate cleanup without fade
	queue_free()


# Optional: React to collisions
func _on_body_entered(body: Node) -> void:
	# Could spawn impact particles, play sound, etc.
	pass




func set_fragment_material(material: Material) -> void:
	if cutout_mesh_instance:
		var mesh_inst := cutout_mesh_instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			mesh_inst.material_override = material


func disable_physics() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0


func enable_physics() -> void:
	freeze = false
	collision_layer = 1
	collision_mask = 1

static func calculate_polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.size() < 3:
		return Vector2.ZERO

	var area := 0.0
	var cx := 0.0
	var cy := 0.0

	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var cross := polygon[i].x * polygon[j].y - polygon[j].x * polygon[i].y
		area += cross
		cx += (polygon[i].x + polygon[j].x) * cross
		cy += (polygon[i].y + polygon[j].y) * cross

	area *= 0.5
	if abs(area) < 0.0001:  # Avoid division by zero
		return Vector2.ZERO

	cx /= (6.0 * area)
	cy /= (6.0 * area)

	return Vector2(cx, cy)

