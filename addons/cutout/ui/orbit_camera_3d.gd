@tool
class_name OrbitCamera3D
extends Camera3D

## Orbit camera controller with mouse drag rotation and scroll wheel zoom.
## Designed for use in SubViewport preview panels.
## Call handle_input() from the parent SubViewportContainer's gui_input signal.

## Target point the camera orbits around
@export var pivot: Vector3 = Vector3.ZERO:
	set(value):
		pivot = value
		_update_camera_transform()

## Distance from the pivot point
@export var distance: float = 2.0:
	set(value):
		distance = clampf(value, min_distance, max_distance)
		_update_camera_transform()

## Horizontal rotation angle (radians)
@export var orbit_x: float = 0.3:
	set(value):
		orbit_x = value
		_update_camera_transform()

## Vertical rotation angle (radians)
@export var orbit_y: float = 0.5:
	set(value):
		orbit_y = clampf(value, -PI / 2.0 + 0.1, PI / 2.0 - 0.1)
		_update_camera_transform()

## Mouse sensitivity for orbit rotation
@export var orbit_sensitivity: float = 0.005

## Scroll wheel zoom sensitivity
@export var zoom_sensitivity: float = 0.1

## Minimum zoom distance
@export var min_distance: float = 0.5

## Maximum zoom distance
@export var max_distance: float = 10.0

## Enable/disable camera controls
@export var controls_enabled: bool = true

var _is_dragging: bool = false


func _ready() -> void:
	_update_camera_transform()


func _update_camera_transform() -> void:
	# Calculate camera position in spherical coordinates around pivot
	var offset := Vector3.ZERO
	offset.x = distance * cos(orbit_y) * sin(orbit_x)
	offset.y = distance * sin(orbit_y)
	offset.z = distance * cos(orbit_y) * cos(orbit_x)

	global_position = pivot + offset
	look_at(pivot, Vector3.UP)


## Handle input event - call this from SubViewportContainer's gui_input
func handle_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		# Middle mouse or right mouse for orbit
		if [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT].has(mouse_event.button_index):
			_is_dragging = mouse_event.pressed

		# Scroll wheel for zoom
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= zoom_sensitivity * distance
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += zoom_sensitivity * distance

	elif event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		orbit_x -= motion.relative.x * orbit_sensitivity
		orbit_y += motion.relative.y * orbit_sensitivity


## Reset camera to default orbit position
func reset_orbit() -> void:
	orbit_x = 0.3
	orbit_y = 0.5
	distance = 2.0


## Fit camera to view a mesh of the given size
func fit_to_bounds(bounds_size: Vector3, center: Vector3 = Vector3.ZERO) -> void:
	pivot = center

	# Calculate distance needed to fit the mesh in view
	var max_extent: float = maxf(bounds_size.x, maxf(bounds_size.y, bounds_size.z))
	if max_extent > 0:
		# Use FOV to calculate appropriate distance
		var fov_rad := deg_to_rad(fov)
		distance = (max_extent / 2.0) / tan(fov_rad / 2.0) * 1.5  # 1.5x for padding
		distance = clampf(distance, min_distance, max_distance)

	_update_camera_transform()
