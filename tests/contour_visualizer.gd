@tool
extends Node2D
class_name ContourVisualizer

## Visualizes the contour polygon output from CutoutContourAlgorithm
## This is a test/debug tool for visualizing algorithm results in the editor

## The texture to extract contours from
@export var texture: Texture2D:
	set(value):
		texture = value
		_recalculate_contour()
		queue_redraw()

## The contour algorithm to use
@export var algorithm: CutoutContourAlgorithm:
	set(value):
		if algorithm != null and algorithm.changed.is_connected(_on_algorithm_changed):
			algorithm.changed.disconnect(_on_algorithm_changed)

		algorithm = value

		if algorithm != null:
			algorithm.changed.connect(_on_algorithm_changed)

		_recalculate_contour()
		queue_redraw()

## Visual settings
@export_group("Visualization")
@export var show_texture: bool = true:
	set(value):
		show_texture = value
		queue_redraw()

@export var contour_color: Color = Color.LIME:
	set(value):
		contour_color = value
		queue_redraw()

@export var contour_width: float = 2.0:
	set(value):
		contour_width = value
		queue_redraw()

@export var show_points: bool = true:
	set(value):
		show_points = value
		queue_redraw()

@export var point_radius: float = 3.0:
	set(value):
		point_radius = value
		queue_redraw()

@export var point_color: Color = Color.RED:
	set(value):
		point_color = value
		queue_redraw()

# Cached contour data
var _contour_points: Array[PackedVector2Array] = []


func _ready() -> void:
	_recalculate_contour()


func _recalculate_contour() -> void:
	_contour_points.clear()

	if texture == null or algorithm == null:
		return

	# Get the image from the texture
	var image = texture.get_image()
	if image == null:
		return

	# Calculate the boundary using the algorithm
	_contour_points = algorithm.calculate_boundary(image)

	queue_redraw()


func _on_algorithm_changed() -> void:
	_recalculate_contour()
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return

	# Draw the source texture as background
	if show_texture:
		draw_texture(texture, Vector2.ZERO)

	# Draw the contour polygons
	if _contour_points.is_empty():
		return

	for contour in _contour_points:
		if contour.is_empty():
			continue

		# Draw lines connecting the points
		for i in range(contour.size()):
			var p1 = contour[i]
			var p2 = contour[(i + 1) % contour.size()]
			draw_line(p1, p2, contour_color, contour_width)

		# Draw individual points
		if show_points:
			for point in contour:
				draw_circle(point, point_radius, point_color)
