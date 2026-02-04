@tool
class_name PanZoomCamera2D
extends Camera2D

## 2D camera controller with mouse drag panning and scroll wheel zoom.
## Designed for use in SubViewport preview panels.
## Call handle_input() from the parent SubViewportContainer's gui_input signal.

## Mouse sensitivity for panning
@export var pan_sensitivity: float = 1.0

## Scroll wheel zoom sensitivity
@export var zoom_sensitivity: float = 0.1

## Minimum zoom level (zoomed out)
@export var min_zoom: float = 0.1

## Maximum zoom level (zoomed in)
@export var max_zoom: float = 10.0

## Enable/disable camera controls
@export var controls_enabled: bool = true

var _is_panning: bool = false


func _ready() -> void:
	pass


## Handle input event - call this from SubViewportContainer's gui_input
func handle_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		# Middle mouse or right mouse for panning
		if [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT].has(mouse_event.button_index):
			_is_panning = mouse_event.pressed

		# Scroll wheel for zoom
		if mouse_event.pressed:
			var zoom_factor := 1.0
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_factor = 1.0 + zoom_sensitivity
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_factor = 1.0 - zoom_sensitivity

			if zoom_factor != 1.0:
				# Zoom towards mouse position
				var mouse_pos: Vector2 = mouse_event.position
				var mouse_world_before := _screen_to_world(mouse_pos)

				# Apply zoom
				var new_zoom := zoom * zoom_factor
				new_zoom.x = clampf(new_zoom.x, min_zoom, max_zoom)
				new_zoom.y = clampf(new_zoom.y, min_zoom, max_zoom)
				zoom = new_zoom

				# Adjust position to zoom towards mouse
				var mouse_world_after := _screen_to_world(mouse_pos)
				position += mouse_world_before - mouse_world_after

	elif event is InputEventMouseMotion and _is_panning:
		var motion := event as InputEventMouseMotion
		# Pan in the opposite direction of mouse movement, scaled by zoom
		position -= motion.relative * pan_sensitivity / zoom.x


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return screen_pos

	var viewport_size := viewport.get_visible_rect().size
	var center := viewport_size / 2.0
	var offset := (screen_pos - center) / zoom
	return position + offset


## Reset camera to default position and zoom
func reset_view() -> void:
	position = Vector2.ZERO
	zoom = Vector2.ONE


## Fit camera to view a specific rect
func fit_to_rect(rect: Rect2, padding: float = 0.9) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var viewport_size := viewport.get_visible_rect().size

	# Calculate zoom to fit rect
	var scale_x: float = viewport_size.x / rect.size.x
	var scale_y: float = viewport_size.y / rect.size.y
	var fit_zoom: float = minf(scale_x, scale_y) * padding

	fit_zoom = clampf(fit_zoom, min_zoom, max_zoom)

	zoom = Vector2(fit_zoom, fit_zoom)
	position = rect.position + rect.size / 2.0
