extends Node3D

## Main destruction controller for CutoutMeshInstance3D objects
## Handles fracturing, fragment spawning, and physics simulation

const CutoutFragment = preload("res://examples/destruction/cutout_fragment.gd")
const CutoutMesh = preload("res://addons/cutout/resources/cutout_mesh.gd")
const CutoutMeshInstance3D = preload("res://addons/cutout/nodes/cutout_mesh_instance_3d.gd")
const CutoutDestructionVoronoi = preload("res://addons/cutout/resources/destruction/cutout_destruction_voronoi.gd")

signal destroyed()

# Destruction settings
@export_group("Destruction")
@export var destruction_algorithm: CutoutDestructionAlgorithm
@export var min_fragment_size: float = 0.01  # Minimum fragment area to spawn

# Physics settings
@export_group("Physics")
@export var explosion_force: float = 10.0
@export var explosion_upward_bias: float = 0.3
@export var rotation_force: float = 5.0
@export var fragment_mass: float = 1.0
@export var fragment_friction: float = 0.5
@export var fragment_bounce: float = 0.3

# Fragment settings
@export_group("Fragments")
@export var fragment_lifetime: float = 10.0
@export var fade_duration: float = 2.0
@export var use_convex_collision: bool = false  # False = trimesh (more accurate)
@export var collision_layer: int = 1
@export var collision_mask: int = 1

# Visual settings
@export_group("Visual")
@export var hide_original_on_destruct: bool = true
@export var spawn_particles: bool = false
@export var particle_scene: PackedScene

# Audio settings
@export_group("Audio")
@export var play_sound: bool = true
@export var explosion_sound: AudioStream
@export var sound_volume: float = 0.0  # In dB

# Interaction settings
@export_group("Interaction")
@export var interaction_prompt: String = "Press E to Destroy"
@export var can_be_destroyed: bool = true
@export var auto_destruct_delay: float = -1.0  # -1 to disable

# Node references
@onready var mesh_instance: CutoutMeshInstance3D = $CutoutMeshInstance3D
@onready var static_body: StaticBody3D = $StaticBody3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Runtime state
var is_destroyed: bool = false
var original_cutout_mesh: CutoutMesh
var fragments_container: Node3D
var active_fragments: Array[Node3D] = []


func _ready() -> void:
	# Store original mesh for resetting
	if mesh_instance and mesh_instance.cutout_mesh:
		original_cutout_mesh = mesh_instance.cutout_mesh

	# Setup audio
	if audio_player and explosion_sound:
		audio_player.stream = explosion_sound
		audio_player.volume_db = sound_volume

	# Setup auto-destruct if enabled
	if auto_destruct_delay > 0:
		await get_tree().create_timer(auto_destruct_delay).timeout
		if not is_destroyed:
			destruct(Vector3.ZERO)

	# Create fragments container
	fragments_container = Node3D.new()
	fragments_container.name = "Fragments"
	get_parent().add_child(fragments_container)


# Interaction interface methods
func can_interact() -> bool:
	return can_be_destroyed and not is_destroyed


func get_interaction_prompt() -> String:
	return interaction_prompt


func interact() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var force = explosion_force * (global_position - camera.global_position).normalized()
	if can_interact():
		destruct(force)

# Main destruction method
func destruct(force: Vector3, custom_impact_point: Vector2 = Vector2(-1, -1)) -> void:
	print("[destructible_cutout] Destruction initiated.")
	if is_destroyed or not mesh_instance or not mesh_instance.cutout_mesh:
		return

	is_destroyed = true

	# Get the CutoutMesh
	var cutout_mesh := mesh_instance.cutout_mesh

	# Create destruction algorithm
	var destruction := create_destruction_algorithm()

	# Use custom impact point if provided
	if custom_impact_point.x >= 0 and custom_impact_point.y >= 0:
		destruction.impact_point = custom_impact_point

	# Fracture the polygon mask
	var fragments := destruction.fracture(cutout_mesh.mask)

	# Spawn physics fragments for each piece
	var fragment_index := 0
	for fragment_polygon in fragments:
		if is_fragment_valid(fragment_polygon):
			spawn_fragment(fragment_polygon, cutout_mesh, fragment_index, force)
			fragment_index += 1

	# Play explosion sound
	if play_sound and audio_player:
		audio_player.play()

	# Spawn particles
	if spawn_particles and particle_scene:
		spawn_destruction_particles()

	# Hide original mesh
	if hide_original_on_destruct:
		mesh_instance.visible = false
		if static_body:
			static_body.collision_layer = 0
			static_body.collision_mask = 0

	# Emit signal for external systems
	destroyed.emit()


func create_destruction_algorithm() -> CutoutDestructionAlgorithm:
	# Use existing algorithm if available, otherwise create a default one
	if not destruction_algorithm:
		destruction_algorithm = CutoutDestructionVoronoi.new()
		destruction_algorithm.pattern = CutoutDestructionVoronoi.SeedPattern.RANDOM

	# Always randomize the seed on each destruction
	destruction_algorithm.seed = randi()

	return destruction_algorithm


func spawn_fragment(polygon: PackedVector2Array, original_mesh: CutoutMesh, index: int, initial_force: Vector3 = Vector3.ZERO) -> void:
	# Create fragment CutoutMesh
	# var fragment_mesh := CutoutMesh.new()
	# fragment_mesh.texture = original_mesh.texture
	# fragment_mesh.depth = original_mesh.depth
	var fragment_mesh := original_mesh.duplicate(true)
	fragment_mesh.mask.assign([polygon])
	fragment_mesh.mesh_size = original_mesh.mesh_size
	fragment_mesh.extrusion_texture_scale = original_mesh.extrusion_texture_scale

	# Create fragment instance
	var fragment := CutoutFragment.new()

	# Add to scene
	fragments_container.add_child(fragment)
	active_fragments.append(fragment)

	# Setup fragment
	fragment.setup(
		fragment_mesh,
		mesh_instance.global_position,
		mesh_instance.global_rotation,
		explosion_force,
		rotation_force,
		fragment_lifetime,
		fade_duration
	)

	# Configure physics
	fragment.mass = fragment_mass
	fragment.physics_material_override = PhysicsMaterial.new()
	fragment.physics_material_override.friction = fragment_friction
	fragment.physics_material_override.bounce = fragment_bounce
	fragment.collision_layer = collision_layer
	fragment.collision_mask = collision_mask
	fragment.use_convex_collision = use_convex_collision

	# Position fragment at original mesh location
	# fragment.global_position = mesh_instance.global_position
	# fragment.global_rotation = mesh_instance.global_rotation
	
	# Apply explosion force with upward bias
	var explosion_center := mesh_instance.global_position
	var fragment_direction := (fragment.global_position - explosion_center).normalized()

	if fragment_direction.is_zero_approx():
		fragment_direction = Vector3(randf() - 0.5, randf(), randf() - 0.5).normalized()

	fragment_direction.y += explosion_upward_bias
	fragment_direction = fragment_direction.normalized()

	# Delay physics activation slightly to ensure proper setup
	fragment.call_deferred("apply_explosion_force", fragment_direction, explosion_force, rotation_force, initial_force)

	


	# Connect cleanup signal
	fragment.tree_exited.connect(_on_fragment_freed.bind(fragment))




func is_fragment_valid(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false

	# Calculate area to filter out tiny fragments
	var area := 0.0
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	area = abs(area) * 0.5

	return area >= min_fragment_size


func spawn_destruction_particles() -> void:
	if not particle_scene:
		return

	var particles := particle_scene.instantiate()
	particles.global_position = mesh_instance.global_position
	get_parent().add_child(particles)

	# Auto-remove particles after a delay
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func reset() -> void:
	if not original_cutout_mesh:
		return

	# Clear existing fragments
	clear_fragments()

	# Restore original mesh
	is_destroyed = false
	mesh_instance.cutout_mesh = original_cutout_mesh
	mesh_instance.visible = true

	if static_body:
		static_body.collision_layer = 1
		static_body.collision_mask = 1


func clear_fragments() -> void:
	for fragment in active_fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	active_fragments.clear()


func _on_fragment_freed(fragment: Node3D) -> void:
	active_fragments.erase(fragment)


# Utility methods for external control
func set_destruction_algorithm(algorithm: CutoutDestructionAlgorithm) -> void:
	destruction_algorithm = algorithm


func get_fragment_count() -> int:
	return active_fragments.size()


func _exit_tree() -> void:
	clear_fragments()
	if is_instance_valid(fragments_container):
		fragments_container.queue_free()
