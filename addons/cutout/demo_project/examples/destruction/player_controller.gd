extends CharacterBody3D

## First-person character controller for the destruction showcase
## Handles movement, jumping, sprinting, and mouse look

# Movement settings
@export_group("Movement")
@export var movement_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var acceleration: float = 10.0
@export var friction: float = 10.0

# Mouse settings
@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.002
@export var vertical_look_limit: float = 89.0  # Degrees

# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# Runtime variables
var mouse_captured: bool = true


func _ready() -> void:
	# Capture mouse for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion and mouse_captured:
		rotate_camera(event.relative)

	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Determine current speed (sprint or normal)
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else movement_speed

	# Apply movement with acceleration
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	move_and_slide()


func rotate_camera(mouse_delta: Vector2) -> void:
	# Horizontal rotation (Y-axis) - rotate the player body
	rotate_y(-mouse_delta.x * mouse_sensitivity)

	# Vertical rotation (X-axis) - rotate the head/camera
	head.rotate_x(-mouse_delta.y * mouse_sensitivity)

	# Clamp vertical rotation to prevent over-rotation
	var clamped_x_rotation: float = clamp(head.rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))
	head.rotation.x = clamped_x_rotation


func toggle_mouse_capture() -> void:
	mouse_captured = !mouse_captured

	if mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func get_camera() -> Camera3D:
	return camera


func get_look_direction() -> Vector3:
	return -camera.global_transform.basis.z


func reset_position(new_position: Vector3) -> void:
	global_position = new_position
	velocity = Vector3.ZERO
	head.rotation.x = 0
	rotation.y = 0