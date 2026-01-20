@tool
extends Node2D
class_name ImagePolygonVisualizer

## Visualizes the full pipeline: Texture → Contour Algorithm → Polygon Simplification
## This is a test/debug tool for visualizing the complete image-to-simplified-polygon pipeline

## The texture to extract contours from
@export var texture: Texture2D:
	set(value):
		texture = value
		_recalculate_pipeline()
		queue_redraw()

## The contour algorithm to use
@export var contour_algorithm: CutoutContourAlgorithm:
	set(value):
		if contour_algorithm != null and contour_algorithm.changed.is_connected(_on_contour_algorithm_changed):
			contour_algorithm.changed.disconnect(_on_contour_algorithm_changed)

		contour_algorithm = value

		if contour_algorithm != null:
			contour_algorithm.changed.connect(_on_contour_algorithm_changed)

		_recalculate_pipeline()
		queue_redraw()

## The polygon simplification algorithm to use
@export var polysimp_algorithm: CutoutPolysimpAlgorithm:
	set(value):
		if polysimp_algorithm != null and polysimp_algorithm.changed.is_connected(_on_polysimp_algorithm_changed):
			polysimp_algorithm.changed.disconnect(_on_polysimp_algorithm_changed)

		polysimp_algorithm = value

		if polysimp_algorithm != null:
			polysimp_algorithm.changed.connect(_on_polysimp_algorithm_changed)

		_recalculate_pipeline()
		queue_redraw()

## The smoothing algorithm to use (optional)
@export var smooth_algorithm: CutoutSmoothAlgorithm:
	set(value):
		if smooth_algorithm != null and smooth_algorithm.changed.is_connected(_on_smooth_algorithm_changed):
			smooth_algorithm.changed.disconnect(_on_smooth_algorithm_changed)

		smooth_algorithm = value

		if smooth_algorithm != null:
			smooth_algorithm.changed.connect(_on_smooth_algorithm_changed)

		_recalculate_pipeline()
		queue_redraw()

## Visual settings - Texture
@export_group("Visualization - Texture")
@export var show_texture: bool = true:
	set(value):
		show_texture = value
		queue_redraw()

## Visual settings - Contour
@export_group("Visualization - Contour")
@export var show_contour: bool = true:
	set(value):
		show_contour = value
		queue_redraw()

@export var contour_color: Color = Color.LIME:
	set(value):
		contour_color = value
		queue_redraw()

@export var contour_width: float = 2.0:
	set(value):
		contour_width = value
		queue_redraw()

@export var show_contour_points: bool = false:
	set(value):
		show_contour_points = value
		queue_redraw()

@export var contour_point_radius: float = 2.0:
	set(value):
		contour_point_radius = value
		queue_redraw()

@export var contour_point_color: Color = Color.YELLOW:
	set(value):
		contour_point_color = value
		queue_redraw()

## Visual settings - Simplified
@export_group("Visualization - Simplified")
@export var show_simplified: bool = true:
	set(value):
		show_simplified = value
		queue_redraw()

@export var simplified_color: Color = Color.RED:
	set(value):
		simplified_color = value
		queue_redraw()

@export var simplified_width: float = 3.0:
	set(value):
		simplified_width = value
		queue_redraw()

@export var show_simplified_points: bool = true:
	set(value):
		show_simplified_points = value
		queue_redraw()

@export var simplified_point_radius: float = 4.0:
	set(value):
		simplified_point_radius = value
		queue_redraw()

@export var simplified_point_color: Color = Color.WHITE:
	set(value):
		simplified_point_color = value
		queue_redraw()

## Visual settings - Smoothed
@export_group("Visualization - Smoothed")
@export var show_smoothed: bool = true:
	set(value):
		show_smoothed = value
		queue_redraw()

@export var smoothed_color: Color = Color.CYAN:
	set(value):
		smoothed_color = value
		queue_redraw()

@export var smoothed_width: float = 2.5:
	set(value):
		smoothed_width = value
		queue_redraw()

@export var show_smoothed_points: bool = false:
	set(value):
		show_smoothed_points = value
		queue_redraw()

@export var smoothed_point_radius: float = 3.0:
	set(value):
		smoothed_point_radius = value
		queue_redraw()

@export var smoothed_point_color: Color = Color.BLUE:
	set(value):
		smoothed_point_color = value
		queue_redraw()

@export_group("Point List")
@export var show_point_list: bool = true:
	set(value):
		show_point_list = value
		_update_point_list()

# Cached pipeline data
var _contour_polygons: Array[PackedVector2Array] = []
var _simplified_polygons: Array[PackedVector2Array] = []
var _smoothed_polygons: Array[PackedVector2Array] = []
var _points_label: Label


func _ready() -> void:
	_points_label = $ScrollContainer/PointsLabel
	_recalculate_pipeline()


func _recalculate_pipeline() -> void:
	_contour_polygons.clear()
	_simplified_polygons.clear()
	_smoothed_polygons.clear()

	if texture == null or contour_algorithm == null:
		_update_point_list()
		return

	# Get the image from the texture
	var image = texture.get_image()
	if image == null:
		_update_point_list()
		return

	# Step 1: Extract contours from texture
	_contour_polygons = contour_algorithm.calculate_boundary(image)

	# Step 2: Simplify each contour polygon (if simplification algorithm is set)
	if polysimp_algorithm != null:
		for contour in _contour_polygons:
			if contour.is_empty():
				_simplified_polygons.append(PackedVector2Array())
			else:
				_simplified_polygons.append(polysimp_algorithm.simplify(contour))
	else:
		# If no simplification algorithm, use contours as-is
		_simplified_polygons = _contour_polygons.duplicate()

	# Step 3: Smooth each polygon (if smoothing algorithm is set)
	if smooth_algorithm != null:
		for simplified in _simplified_polygons:
			if simplified.is_empty():
				_smoothed_polygons.append(PackedVector2Array())
			else:
				_smoothed_polygons.append(smooth_algorithm.smooth(simplified))
	else:
		# If no smoothing algorithm, use simplified as-is
		_smoothed_polygons = _simplified_polygons.duplicate()

	_update_point_list()
	queue_redraw()


func _update_point_list() -> void:
	if not is_node_ready():
		return

	if not show_point_list or _contour_polygons.is_empty():
		_points_label.text = "No pipeline data"
		return

	var text := ""

	for polygon_idx in range(_contour_polygons.size()):
		var contour = _contour_polygons[polygon_idx]
		var simplified = _simplified_polygons[polygon_idx] if polygon_idx < _simplified_polygons.size() else PackedVector2Array()
		var smoothed = _smoothed_polygons[polygon_idx] if polygon_idx < _smoothed_polygons.size() else PackedVector2Array()

		if polygon_idx > 0:
			text += "\n========================================\n"

		text += "[Polygon %d]\n" % polygon_idx

		# Original contour info
		if contour.is_empty():
			text += "  [Contour - Empty]\n"
		else:
			text += "  [Contour - %d points]\n" % contour.size()
			for i in range(min(contour.size(), 5)):  # Show first 5 points
				var point = contour[i]
				text += "    [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
			if contour.size() > 5:
				text += "    ... (%d more points)\n" % (contour.size() - 5)

		# Simplified polygon info
		if simplified.is_empty():
			text += "  [Simplified - Empty]\n"
		else:
			text += "  [Simplified - %d points]\n" % simplified.size()
			for i in range(min(simplified.size(), 5)):  # Show first 5 points
				var point = simplified[i]
				text += "    [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
			if simplified.size() > 5:
				text += "    ... (%d more points)\n" % (simplified.size() - 5)

		# Smoothed polygon info
		if smooth_algorithm and not smoothed.is_empty():
			text += "  [Smoothed - %d points]\n" % smoothed.size()
			for i in range(min(smoothed.size(), 5)):  # Show first 5 points
				var point = smoothed[i]
				text += "    [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
			if smoothed.size() > 5:
				text += "    ... (%d more points)\n" % (smoothed.size() - 5)

		# Reduction stats
		if not contour.is_empty() and not simplified.is_empty():
			var reduction = (1.0 - float(simplified.size()) / float(contour.size())) * 100.0
			text += "  Simplification: %.1f%% (%d → %d points)\n" % [reduction, contour.size(), simplified.size()]

		if smooth_algorithm and not simplified.is_empty() and not smoothed.is_empty():
			var smooth_change = (float(smoothed.size()) - float(simplified.size())) / float(simplified.size()) * 100.0
			if abs(smooth_change) > 0.1:
				text += "  Smoothing: %+.1f%% (%d → %d points)\n" % [smooth_change, simplified.size(), smoothed.size()]

	_points_label.text = text


func _on_contour_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _on_polysimp_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _on_smooth_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return

	# Draw the source texture as background
	if show_texture:
		draw_texture(texture, Vector2.ZERO)

	if _contour_polygons.is_empty():
		return

	# Draw contour polygons
	if show_contour:
		for contour in _contour_polygons:
			if contour.is_empty():
				continue

			# Draw lines connecting the points
			for i in range(contour.size()):
				var p1 = contour[i]
				var p2 = contour[(i + 1) % contour.size()]
				draw_line(p1, p2, contour_color, contour_width)

			# Draw contour points
			if show_contour_points:
				for point in contour:
					draw_circle(point, contour_point_radius, contour_point_color)

	# Draw simplified polygons
	if show_simplified:
		for simplified in _simplified_polygons:
			if simplified.is_empty():
				continue

			# Draw lines connecting the points
			for i in range(simplified.size()):
				var p1 = simplified[i]
				var p2 = simplified[(i + 1) % simplified.size()]
				draw_line(p1, p2, simplified_color, simplified_width)

			# Draw simplified points
			if show_simplified_points:
				for point in simplified:
					draw_circle(point, simplified_point_radius, simplified_point_color)

	print("_smoothed_polygons", _smoothed_polygons)
	# Draw smoothed polygons
	if show_smoothed and smooth_algorithm:
		for smoothed in _smoothed_polygons:
			print("smoothed", smoothed)
			if smoothed.is_empty():
				continue

			# Draw lines connecting the points
			for i in range(smoothed.size()):
				var p1 = smoothed[i]
				var p2 = smoothed[(i + 1) % smoothed.size()]
				draw_line(p1, p2, smoothed_color, smoothed_width)

			# Draw smoothed points
			if show_smoothed_points:
				for point in smoothed:
					draw_circle(point, smoothed_point_radius, smoothed_point_color)
