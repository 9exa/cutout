@tool
extends Node2D

## Visualizes polygon destruction/fracture output in real-time.
## Select a preset polygon shape or use custom polygons, then apply a destruction algorithm.
## Follows the same pattern as ContourVisualizer for consistency.


## Preset polygon shapes for quick testing
enum PolygonPreset {
	CUSTOM,           ## Use custom source_polygons array
	SQUARE,           ## Simple 200x200 square
	RECTANGLE,        ## 300x200 rectangle
	DONUT,            ## Square with circular hole (donut shape)
	SWISS_CHEESE,     ## Square with multiple circular holes
	PICTURE_FRAME,    ## Square with square hole (frame shape)
	L_SHAPE,          ## L-shaped polygon (no holes)
	HEXAGON,          ## Regular hexagon
	STAR,             ## 5-pointed star
}

## Select a preset polygon shape or use CUSTOM for manual polygons
@export var polygon_preset: PolygonPreset = PolygonPreset.DONUT:
	set(value):
		polygon_preset = value
		_generate_preset_polygon()
		_recalculate_destruction()
		queue_redraw()

## The source polygons to fracture (first = outer boundary, rest = holes)
## Only used when polygon_preset is CUSTOM
@export var source_polygons: Array[PackedVector2Array]:
	set(value):
		source_polygons = value
		if polygon_preset == PolygonPreset.CUSTOM:
			_recalculate_destruction()
			queue_redraw()

## The destruction algorithm to use
@export var destruction_algorithm: CutoutDestructionAlgorithm:
	set(value):
		if destruction_algorithm != null and destruction_algorithm.changed.is_connected(_on_algorithm_changed):
			destruction_algorithm.changed.disconnect(_on_algorithm_changed)

		destruction_algorithm = value

		if destruction_algorithm != null:
			destruction_algorithm.changed.connect(_on_algorithm_changed)

		_recalculate_destruction()
		queue_redraw()


## Visualization settings
@export_group("Visualization - Original Polygon")
@export var show_original: bool = true:
	set(value):
		show_original = value
		queue_redraw()

@export var original_color: Color = Color(0.5, 0.5, 0.5, 0.2):
	set(value):
		original_color = value
		queue_redraw()

@export var original_outline_color: Color = Color.WHITE:
	set(value):
		original_outline_color = value
		queue_redraw()

@export var original_outline_width: float = 1.0:
	set(value):
		original_outline_width = value
		queue_redraw()

@export var hole_color: Color = Color(0.2, 0.2, 0.2, 0.5):
	set(value):
		hole_color = value
		queue_redraw()

@export var hole_outline_color: Color = Color.RED:
	set(value):
		hole_outline_color = value
		queue_redraw()


@export_group("Visualization - Fragments")
@export var show_fragments: bool = true:
	set(value):
		show_fragments = value
		queue_redraw()

@export var colorize_fragments: bool = true:
	set(value):
		colorize_fragments = value
		queue_redraw()

@export var fragment_alpha: float = 0.6:
	set(value):
		fragment_alpha = value
		queue_redraw()

@export var fragment_outline_color: Color = Color.CYAN:
	set(value):
		fragment_outline_color = value
		queue_redraw()

@export var fragment_outline_width: float = 2.0:
	set(value):
		fragment_outline_width = value
		queue_redraw()


@export_group("Debug Info")
@export var show_fragment_count: bool = true:
	set(value):
		show_fragment_count = value
		queue_redraw()

@export var show_seed_points: bool = true:
	set(value):
		show_seed_points = value
		queue_redraw()

@export var seed_point_color: Color = Color.RED:
	set(value):
		seed_point_color = value
		queue_redraw()

@export var seed_point_radius: float = 4.0:
	set(value):
		seed_point_radius = value
		queue_redraw()

@export var show_voronoi_vertices: bool = false:
	set(value):
		show_voronoi_vertices = value
		queue_redraw()

@export var voronoi_vertex_color: Color = Color.ORANGE:
	set(value):
		voronoi_vertex_color = value
		queue_redraw()

@export var voronoi_vertex_radius: float = 3.0:
	set(value):
		voronoi_vertex_radius = value
		queue_redraw()


# Cached fragments
var _fragments: Array[PackedVector2Array] = []

# Active polygons (either from preset or custom)
var _active_polygons: Array[PackedVector2Array] = []


func _ready() -> void:
	_generate_preset_polygon()
	_recalculate_destruction()


## Generates the preset polygon based on the selected enum value
func _generate_preset_polygon() -> void:
	if polygon_preset == PolygonPreset.CUSTOM:
		# Ensure source_polygons is valid
		if source_polygons.is_empty():
			push_warning("DestructionVisualizer: CUSTOM preset selected but source_polygons is empty")
			_active_polygons.clear()
			return
		_active_polygons = source_polygons.duplicate(true)
		return

	_active_polygons.clear()

	match polygon_preset:
		PolygonPreset.SQUARE:
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(200, 0),
				Vector2(200, 200),
				Vector2(0, 200)
			]))

		PolygonPreset.RECTANGLE:
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(300, 0),
				Vector2(300, 200),
				Vector2(0, 200)
			]))

		PolygonPreset.DONUT:
			# Outer square
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(200, 0),
				Vector2(200, 200),
				Vector2(0, 200)
			]))
			# Circular hole in center (12-sided polygon)
			var hole := PackedVector2Array()
			var center := Vector2(100, 100)
			var radius := 50.0
			for i in range(12):
				var angle := TAU * i / 12
				hole.append(center + Vector2(cos(angle), sin(angle)) * radius)
			_active_polygons.append(hole)

		PolygonPreset.SWISS_CHEESE:
			# Outer square
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(300, 0),
				Vector2(300, 300),
				Vector2(0, 300)
			]))
			# Three circular holes (octagons)
			var hole_centers := [Vector2(80, 80), Vector2(220, 80), Vector2(150, 200)]
			var hole_radius := 30.0
			for center in hole_centers:
				var hole := PackedVector2Array()
				for i in range(8):
					var angle := TAU * i / 8
					hole.append(center + Vector2(cos(angle), sin(angle)) * hole_radius)
				_active_polygons.append(hole)

		PolygonPreset.PICTURE_FRAME:
			# Outer square
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(200, 0),
				Vector2(200, 200),
				Vector2(0, 200)
			]))
			# Inner square hole (frame)
			_active_polygons.append(PackedVector2Array([
				Vector2(50, 50),
				Vector2(150, 50),
				Vector2(150, 150),
				Vector2(50, 150)
			]))

		PolygonPreset.L_SHAPE:
			# L-shaped polygon (no holes)
			_active_polygons.append(PackedVector2Array([
				Vector2(0, 0),
				Vector2(150, 0),
				Vector2(150, 100),
				Vector2(100, 100),
				Vector2(100, 200),
				Vector2(0, 200)
			]))

		PolygonPreset.HEXAGON:
			# Regular hexagon
			var hex := PackedVector2Array()
			var center := Vector2(100, 100)
			var radius := 80.0
			for i in range(6):
				var angle := TAU * i / 6
				hex.append(center + Vector2(cos(angle), sin(angle)) * radius)
			_active_polygons.append(hex)

		PolygonPreset.STAR:
			# 5-pointed star
			var star := PackedVector2Array()
			var center := Vector2(100, 100)
			var outer_radius := 80.0
			var inner_radius := 35.0
			for i in range(10):
				var angle := TAU * i / 10 - PI / 2  # Start at top
				var radius := outer_radius if i % 2 == 0 else inner_radius
				star.append(center + Vector2(cos(angle), sin(angle)) * radius)
			_active_polygons.append(star)


func _recalculate_destruction() -> void:
	_fragments.clear()

	if _active_polygons.is_empty() or destruction_algorithm == null:
		queue_redraw()
		return

	# Run destruction algorithm with error handling
	# Make a copy to avoid modifying the source polygons
	var result := destruction_algorithm.fracture(_active_polygons.duplicate(true))

	if result != null:
		_fragments = result
	else:
		push_warning("DestructionVisualizer: fracture() returned null, keeping previous fragments")

	queue_redraw()


func _on_algorithm_changed() -> void:
	_recalculate_destruction()


func _draw() -> void:
	if _active_polygons.is_empty():
		return

	# Draw original polygons (outer boundary + holes)
	if show_original:
		# Draw outer polygon
		if _active_polygons.size() > 0:
			var outer := _active_polygons[0]

			# Validate outer polygon before drawing
			if outer.size() >= 3:
				# Draw filled
				if original_color.a > 0:
					draw_colored_polygon(outer, original_color)

				# Draw outline
				if original_outline_width > 0 and original_outline_color.a > 0:
					for i in range(outer.size()):
						var p1 := outer[i]
						var p2 := outer[(i + 1) % outer.size()]
						draw_line(p1, p2, original_outline_color, original_outline_width)

		# Draw holes
		for hole_idx in range(1, _active_polygons.size()):
			var hole := _active_polygons[hole_idx]

			# Validate hole before drawing
			if hole.size() >= 3:
				# Draw filled hole (darker)
				if hole_color.a > 0:
					draw_colored_polygon(hole, hole_color)

				# Draw hole outline
				if original_outline_width > 0 and hole_outline_color.a > 0:
					for i in range(hole.size()):
						var p1 := hole[i]
						var p2 := hole[(i + 1) % hole.size()]
						draw_line(p1, p2, hole_outline_color, original_outline_width)

	# Draw fragments
	if show_fragments and not _fragments.is_empty():
		for i in range(_fragments.size()):
			var fragment := _fragments[i]

			if fragment.size() < 3:
				continue

			# Generate color for this fragment
			var color: Color
			if colorize_fragments:
				var hue: float = float(i) / max(_fragments.size(), 1)
				color = Color.from_hsv(hue, 0.7, 0.9, fragment_alpha)
			else:
				color = Color(0.8, 0.8, 0.8, fragment_alpha)

			# Draw filled fragment
			draw_colored_polygon(fragment, color)

			# Draw outline
			if fragment_outline_width > 0 and fragment_outline_color.a > 0:
				for j in range(fragment.size()):
					var p1 := fragment[j]
					var p2 := fragment[(j + 1) % fragment.size()]
					draw_line(p1, p2, fragment_outline_color, fragment_outline_width)

	# Draw seed points (should be centered in fragments)
	if show_seed_points and destruction_algorithm:
		if destruction_algorithm is CutoutDestructionVoronoi:
			var voronoi_algo := destruction_algorithm as CutoutDestructionVoronoi
			if voronoi_algo._debug_seed_points.size() > 0:
				for seed in voronoi_algo._debug_seed_points:
					draw_circle(seed, seed_point_radius, seed_point_color)

	# Draw Voronoi vertices (circumcenters of Delaunay triangles - at edge intersections)
	if show_voronoi_vertices and destruction_algorithm:
		if destruction_algorithm is CutoutDestructionVoronoi:
			var voronoi_algo := destruction_algorithm as CutoutDestructionVoronoi
			if voronoi_algo._debug_voronoi_vertices.size() > 0:
				for vertex in voronoi_algo._debug_voronoi_vertices:
					draw_circle(vertex, voronoi_vertex_radius, voronoi_vertex_color)

	# Draw debug info
	if show_fragment_count and not _fragments.is_empty():
		var text := "Fragments: %d" % _fragments.size()
		draw_string(ThemeDB.fallback_font, Vector2(10, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

		if destruction_algorithm:
			var seed_text := "Seed: %d" % destruction_algorithm.seed
			draw_string(ThemeDB.fallback_font, Vector2(10, 55), seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

			# Show seed point count
			if destruction_algorithm is CutoutDestructionVoronoi:
				var voronoi_algo := destruction_algorithm as CutoutDestructionVoronoi
				var seed_count_text := "Seed Points: %d" % voronoi_algo._debug_seed_points.size()
				draw_string(ThemeDB.fallback_font, Vector2(10, 80), seed_count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

				# Show Voronoi vertex count if visible
				if show_voronoi_vertices:
					var vertex_text := "Voronoi Vertices: %d" % voronoi_algo._debug_voronoi_vertices.size()
					draw_string(ThemeDB.fallback_font, Vector2(10, 105), vertex_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
