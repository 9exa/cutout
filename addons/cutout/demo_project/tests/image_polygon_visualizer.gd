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

## The pre-smoothing polygon simplification algorithm to use
@export var pre_smooth_simp_algorithm: CutoutPolysimpAlgorithm:
	set(value):
		if pre_smooth_simp_algorithm != null and pre_smooth_simp_algorithm.changed.is_connected(_on_pre_smooth_simp_algorithm_changed):
			pre_smooth_simp_algorithm.changed.disconnect(_on_pre_smooth_simp_algorithm_changed)

		pre_smooth_simp_algorithm = value

		if pre_smooth_simp_algorithm != null:
			pre_smooth_simp_algorithm.changed.connect(_on_pre_smooth_simp_algorithm_changed)

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

## The post-smoothing polygon simplification algorithm to use (optional)
@export var post_smooth_simp_algorithm: CutoutPolysimpAlgorithm:
	set(value):
		if post_smooth_simp_algorithm != null and post_smooth_simp_algorithm.changed.is_connected(_on_post_smooth_simp_algorithm_changed):
			post_smooth_simp_algorithm.changed.disconnect(_on_post_smooth_simp_algorithm_changed)

		post_smooth_simp_algorithm = value

		if post_smooth_simp_algorithm != null:
			post_smooth_simp_algorithm.changed.connect(_on_post_smooth_simp_algorithm_changed)

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

## Visual settings - Pre-Smoothed
@export_group("Visualization - Pre-Smoothed")
@export var show_pre_smoothed: bool = true:
	set(value):
		show_pre_smoothed = value
		queue_redraw()

@export var pre_smoothed_color: Color = Color.RED:
	set(value):
		pre_smoothed_color = value
		queue_redraw()

@export var pre_smoothed_width: float = 3.0:
	set(value):
		pre_smoothed_width = value
		queue_redraw()

@export var show_pre_smoothed_points: bool = true:
	set(value):
		show_pre_smoothed_points = value
		queue_redraw()

@export var pre_smoothed_point_radius: float = 4.0:
	set(value):
		pre_smoothed_point_radius = value
		queue_redraw()

@export var pre_smoothed_point_color: Color = Color.WHITE:
	set(value):
		pre_smoothed_point_color = value
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

## Visual settings - Post-Smoothed
@export_group("Visualization - Post-Smoothed")
@export var show_post_smoothed: bool = true:
	set(value):
		show_post_smoothed = value
		queue_redraw()

@export var post_smoothed_color: Color = Color.MAGENTA:
	set(value):
		post_smoothed_color = value
		queue_redraw()

@export var post_smoothed_width: float = 3.5:
	set(value):
		post_smoothed_width = value
		queue_redraw()

@export var show_post_smoothed_points: bool = true:
	set(value):
		show_post_smoothed_points = value
		queue_redraw()

@export var post_smoothed_point_radius: float = 5.0:
	set(value):
		post_smoothed_point_radius = value
		queue_redraw()

@export var post_smoothed_point_color: Color = Color.YELLOW:
	set(value):
		post_smoothed_point_color = value
		queue_redraw()

@export_group("Point List Labels")
@export var contour_points_label: Label:
	set(value):
		contour_points_label = value
		_update_point_list()

@export var pre_smoothed_points_label: Label:
	set(value):
		pre_smoothed_points_label = value
		_update_point_list()

@export var smoothed_points_label: Label:
	set(value):
		smoothed_points_label = value
		_update_point_list()

@export var post_smoothed_points_label: Label:
	set(value):
		post_smoothed_points_label = value
		_update_point_list()

@export_group("Output Polygons")
## The final calculated polygon (read-only, for copying in the editor)
@export var output_final_polygon: Array[PackedVector2Array]:
	get:
		# Return the most processed polygon available
		if not _post_smoothed_polygons.is_empty():
			return _post_smoothed_polygons.duplicate()
		elif not _smoothed_polygons.is_empty():
			return _smoothed_polygons.duplicate()
		elif not _pre_smoothed_polygons.is_empty():
			return _pre_smoothed_polygons.duplicate()
		else:
			return _contour_polygons.duplicate()

# Cached pipeline data
var _contour_polygons: Array[PackedVector2Array] = []
var _pre_smoothed_polygons: Array[PackedVector2Array] = []
var _smoothed_polygons: Array[PackedVector2Array] = []
var _post_smoothed_polygons: Array[PackedVector2Array] = []


func _ready() -> void:
	_recalculate_pipeline()


func _recalculate_pipeline() -> void:
	_contour_polygons.clear()
	_pre_smoothed_polygons.clear()
	_smoothed_polygons.clear()
	_post_smoothed_polygons.clear()

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
	if pre_smooth_simp_algorithm != null:
		for contour in _contour_polygons:
			if contour.is_empty():
				_pre_smoothed_polygons.append(PackedVector2Array())
			else:
				_pre_smoothed_polygons.append(pre_smooth_simp_algorithm.simplify(contour))
	else:
		# If no simplification algorithm, use contours as-is
		_pre_smoothed_polygons = _contour_polygons.duplicate()

	# Step 3: Smooth each polygon (if smoothing algorithm is set)
	if smooth_algorithm != null:
		for pre_smoothed in _pre_smoothed_polygons:
			if pre_smoothed.is_empty():
				_smoothed_polygons.append(PackedVector2Array())
			else:
				_smoothed_polygons.append(smooth_algorithm.smooth(pre_smoothed))
	else:
		# If no smoothing algorithm, use pre-smoothed as-is
		_smoothed_polygons = _pre_smoothed_polygons.duplicate()

	# Step 4: Post-smooth simplification (if algorithm is set)
	if post_smooth_simp_algorithm != null:
		for smoothed in _smoothed_polygons:
			if smoothed.is_empty():
				_post_smoothed_polygons.append(PackedVector2Array())
			else:
				_post_smoothed_polygons.append(post_smooth_simp_algorithm.simplify(smoothed))
	else:
		# If no post-smooth simplification algorithm, use smoothed as-is
		_post_smoothed_polygons = _smoothed_polygons.duplicate()

	_update_point_list()
	queue_redraw()


func _update_point_list() -> void:
	if not is_node_ready():
		return

	# Update contour points label
	if contour_points_label:
		var contour_text := ""
		if _contour_polygons.is_empty():
			contour_text = "[Contour - No data]"
		else:
			for polygon_idx in range(_contour_polygons.size()):
				var contour = _contour_polygons[polygon_idx]
				if polygon_idx > 0:
					contour_text += "\n"
				contour_text += "[Polygon %d - %d points]\n" % [polygon_idx, contour.size()]
				for i in range(contour.size()):
					var point = contour[i]
					contour_text += "  [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
		contour_points_label.text = contour_text

	# Update pre-smoothed points label
	if pre_smoothed_points_label:
		var pre_smoothed_text := ""
		if _pre_smoothed_polygons.is_empty():
			pre_smoothed_text = "[Pre-Smoothed - No data]"
		else:
			for polygon_idx in range(_pre_smoothed_polygons.size()):
				var pre_smoothed = _pre_smoothed_polygons[polygon_idx]
				if polygon_idx > 0:
					pre_smoothed_text += "\n"
				pre_smoothed_text += "[Polygon %d - %d points]\n" % [polygon_idx, pre_smoothed.size()]
				for i in range(pre_smoothed.size()):
					var point = pre_smoothed[i]
					pre_smoothed_text += "  [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
		pre_smoothed_points_label.text = pre_smoothed_text

	# Update smoothed points label
	if smoothed_points_label:
		var smoothed_text := ""
		if _smoothed_polygons.is_empty() or smooth_algorithm == null:
			smoothed_text = "[Smoothed - No data]"
		else:
			for polygon_idx in range(_smoothed_polygons.size()):
				var smoothed = _smoothed_polygons[polygon_idx]
				if polygon_idx > 0:
					smoothed_text += "\n"
				smoothed_text += "[Polygon %d - %d points]\n" % [polygon_idx, smoothed.size()]
				for i in range(smoothed.size()):
					var point = smoothed[i]
					smoothed_text += "  [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
		smoothed_points_label.text = smoothed_text

	# Update post-smoothed points label
	if post_smoothed_points_label:
		var post_smoothed_text := ""
		if _post_smoothed_polygons.is_empty() or post_smooth_simp_algorithm == null:
			post_smoothed_text = "[Post-Smoothed - No data]"
		else:
			for polygon_idx in range(_post_smoothed_polygons.size()):
				var post_smoothed = _post_smoothed_polygons[polygon_idx]
				if polygon_idx > 0:
					post_smoothed_text += "\n"
				post_smoothed_text += "[Polygon %d - %d points]\n" % [polygon_idx, post_smoothed.size()]
				for i in range(post_smoothed.size()):
					var point = post_smoothed[i]
					post_smoothed_text += "  [%d]: (%.2f, %.2f)\n" % [i, point.x, point.y]
		post_smoothed_points_label.text = post_smoothed_text


func _on_contour_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _on_pre_smooth_simp_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _on_smooth_algorithm_changed() -> void:
	_recalculate_pipeline()
	queue_redraw()


func _on_post_smooth_simp_algorithm_changed() -> void:
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

	# Draw pre-smoothed polygons
	if show_pre_smoothed:
		for pre_smoothed in _pre_smoothed_polygons:
			if pre_smoothed.is_empty():
				continue

			# Draw lines connecting the points
			for i in range(pre_smoothed.size()):
				var p1 = pre_smoothed[i]
				var p2 = pre_smoothed[(i + 1) % pre_smoothed.size()]
				draw_line(p1, p2, pre_smoothed_color, pre_smoothed_width)

			# Draw pre-smoothed points
			if show_pre_smoothed_points:
				for point in pre_smoothed:
					draw_circle(point, pre_smoothed_point_radius, pre_smoothed_point_color)

	# Draw smoothed polygons
	if show_smoothed and smooth_algorithm:
		for smoothed in _smoothed_polygons:
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

	# Draw post-smoothed polygons
	if show_post_smoothed and post_smooth_simp_algorithm:
		for post_smoothed in _post_smoothed_polygons:
			if post_smoothed.is_empty():
				continue

			# Draw lines connecting the points
			for i in range(post_smoothed.size()):
				var p1 = post_smoothed[i]
				var p2 = post_smoothed[(i + 1) % post_smoothed.size()]
				draw_line(p1, p2, post_smoothed_color, post_smoothed_width)

			# Draw post-smoothed points
			if show_post_smoothed_points:
				for point in post_smoothed:
					draw_circle(point, post_smoothed_point_radius, post_smoothed_point_color)
