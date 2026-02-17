@tool
class_name CutoutDestructionVoronoi
extends CutoutDestructionAlgorithm

## Voronoi-based polygon fracture algorithm.
##
## Generates seed points within the polygon using various patterns and creates Voronoi cells
## by computing the Delaunay triangulation and then deriving Voronoi regions.
## Each cell becomes a fragment, clipped to the original polygon boundary.
##
## This creates natural-looking shatter/fracture patterns suitable for glass,
## rock, or other brittle materials.
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).


## Seed point distribution pattern.
enum SeedPattern {
	RANDOM,      ## Pure random distribution - natural shattering
	GRID,        ## Grid-based with jitter - organized destruction (tiles, bricks)
	RADIAL,      ## Concentric rings from center - impact/explosion patterns
	SPIDERWEB,   ## Radial rays + rings - cracked glass effect
	POISSON_DISK ## Blue noise distribution - high-quality natural fractures
}

## The pattern to use for seed point placement.
@export var pattern: SeedPattern = SeedPattern.RANDOM:
	set(value):
		pattern = value
		notify_property_list_changed()
		emit_changed()

## Target number of fragments to generate.
## The actual number may vary depending on the polygon shape and pattern.
@export_range(2, 100, 1) var fragment_count: int = 10:
	set(value):
		fragment_count = value
		emit_changed()

## Minimum distance between Voronoi seed points as a fraction of polygon bounds.
## Prevents cells from becoming too small. Higher values = larger minimum cell size.
@export_range(0.01, 0.5, 0.01) var min_cell_distance: float = 0.1:
	set(value):
		min_cell_distance = value
		emit_changed()

## Padding/margin from polygon edges when placing seed points (in pixels).
## Prevents fragments from being too thin at the edges.
@export_range(0.0, 50.0, 1.0) var edge_padding: float = 5.0:
	set(value):
		edge_padding = value
		emit_changed()

# Pattern-specific parameters (stored privately, exposed dynamically via _get_property_list)
var _grid_rows: int = 3
var _grid_cols: int = 3
var _grid_jitter: float = 0.3
var _origin: Vector2 = Vector2.ZERO
var _ring_count: int = 3
var _ring_size: float = 50.0  # Distance in pixels between rings
var _points_per_ring: int = 8
var _radial_variation: float = 0.2
var _poisson_attempts: int = 30

# Debug: Seed points (centers of Voronoi cells - should be in fragment centers)
var _debug_seed_points: PackedVector2Array = []

# Debug: Voronoi vertices (circumcenters of Delaunay triangles - at edge intersections)
var _debug_voronoi_vertices: PackedVector2Array = []


## Dynamically expose only pattern-relevant properties in the inspector.
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	match pattern:
		SeedPattern.GRID:
			properties.append({
				"name": "grid_rows",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,20,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "grid_cols",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,20,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "grid_jitter",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		SeedPattern.RADIAL, SeedPattern.SPIDERWEB:
			properties.append({
				"name": "origin",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "ring_count",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,10,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "ring_size",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "10.0,200.0,5.0",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "points_per_ring",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "3,24,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "radial_variation",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		SeedPattern.POISSON_DISK:
			properties.append({
				"name": "poisson_attempts",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "10,100,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties


## Get property values for pattern-specific parameters.
func _get(property: StringName):
	match property:
		"grid_rows": return _grid_rows
		"grid_cols": return _grid_cols
		"grid_jitter": return _grid_jitter
		"origin": return _origin
		"ring_count": return _ring_count
		"ring_size": return _ring_size
		"points_per_ring": return _points_per_ring
		"radial_variation": return _radial_variation
		"poisson_attempts": return _poisson_attempts
	return null


## Set property values for pattern-specific parameters.
func _set(property: StringName, value) -> bool:
	match property:
		"grid_rows":
			_grid_rows = value
			emit_changed()
			return true
		"grid_cols":
			_grid_cols = value
			emit_changed()
			return true
		"grid_jitter":
			_grid_jitter = value
			emit_changed()
			return true
		"origin":
			_origin = value
			emit_changed()
			return true
		"ring_count":
			_ring_count = value
			emit_changed()
			return true
		"ring_size":
			_ring_size = value
			emit_changed()
			return true
		"points_per_ring":
			_points_per_ring = value
			emit_changed()
			return true
		"radial_variation":
			_radial_variation = value
			emit_changed()
			return true
		"poisson_attempts":
			_poisson_attempts = value
			emit_changed()
			return true

	return false


## Implementation of Voronoi fracture algorithm.
## Delegates seed generation and fracture to the Rust CutoutDestructionProcessor.
func _fracture(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var outer_polygon := polygons[0]
	var bounds := _calculate_bounds(outer_polygon)

	# Generate seed points via the Rust implementation
	var seed_points := _generate_seed_points_rust(outer_polygon, bounds)

	# Store for debugging
	_debug_seed_points = seed_points.duplicate()

	if seed_points.size() < 2:
		push_warning("CutoutDestructionVoronoi: Not enough valid seed points generated")
		return polygons

	# Delegate Voronoi fracture entirely to Rust
	var fragments := CutoutDestructionProcessor.fracture_voronoi(polygons, seed_points)

	if fragments.is_empty():
		push_warning("CutoutDestructionVoronoi: No valid fragments generated, returning original")
		return polygons

	return fragments


## Dispatches seed generation to the appropriate Rust generator based on pattern.
func _generate_seed_points_rust(outer_polygon: PackedVector2Array, bounds: Rect2) -> PackedVector2Array:
	match pattern:
		SeedPattern.RANDOM:
			return CutoutDestructionProcessor.generate_random_seeds(
				outer_polygon,
				fragment_count,
				min_cell_distance,
				edge_padding,
				seed
			)
		SeedPattern.GRID:
			return CutoutDestructionProcessor.generate_grid_seeds(
				outer_polygon,
				_grid_rows,
				_grid_cols,
				_grid_jitter,
				min_cell_distance,
				edge_padding,
				seed
			)
		SeedPattern.RADIAL:
			var origin := _origin if _origin != Vector2.ZERO else bounds.get_center()
			return CutoutDestructionProcessor.generate_radial_seeds(
				outer_polygon,
				origin,
				_ring_count,
				_ring_size,
				_points_per_ring,
				_radial_variation,
				min_cell_distance,
				seed
			)
		SeedPattern.SPIDERWEB:
			var origin := _origin if _origin != Vector2.ZERO else bounds.get_center()
			return CutoutDestructionProcessor.generate_spiderweb_seeds(
				outer_polygon,
				origin,
				_ring_count,
				_ring_size,
				_points_per_ring,
				_radial_variation,
				min_cell_distance,
				seed
			)
		SeedPattern.POISSON_DISK:
			return CutoutDestructionProcessor.generate_poisson_seeds(
				outer_polygon,
				fragment_count,
				min_cell_distance,
				edge_padding,
				_poisson_attempts,
				seed
			)
		_:
			push_error("Unknown seed pattern: %d" % pattern)
			return PackedVector2Array()


## GDScript reference implementation (kept for fallback/debugging).
## Call this instead of _fracture() if you need the pure-GDScript path.
func _fracture_gdscript(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Initialize random number generator with seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Extract outer polygon (first element) for bounds and seed generation
	var outer_polygon := polygons[0]

	# Calculate polygon bounds (only using outer boundary)
	var bounds := _calculate_bounds(outer_polygon)

	# Generate Voronoi seed points within the outer polygon
	var seed_points := _generate_seed_points(outer_polygon, bounds, rng)

	# Store for debugging
	_debug_seed_points = seed_points.duplicate()

	if seed_points.size() < 2:
		push_warning("CutoutDestructionVoronoi: Not enough valid seed points generated")
		return polygons  # Return original polygons

	# Compute Delaunay triangulation of seed points
	var triangulation := _delaunay_triangulation(seed_points)

	if triangulation.is_empty():
		push_warning("CutoutDestructionVoronoi: Delaunay triangulation failed")
		return polygons

	# Convert Delaunay triangulation to Voronoi cells
	var voronoi_cells := _compute_voronoi_cells(seed_points, triangulation, bounds)

	# Clip each Voronoi cell to the polygon (with holes)
	# Use Geometry2D.clip_polygons which properly handles holes via Clipper library
	var fragments: Array[PackedVector2Array] = []

	# Spatial culling optimization: Precompute hole bounding boxes once
	var hole_bounds: Array[Rect2] = []
	for hole_idx in range(1, polygons.size()):
		hole_bounds.append(_calculate_bounds(polygons[hole_idx]))

	for cell in voronoi_cells:
		# Clip cell against outer polygon first
		var clipped_outer := Geometry2D.intersect_polygons(cell, outer_polygon)

		# Then subtract each hole from each resulting fragment
		for fragment in clipped_outer:
			var remaining := [fragment]

			# Calculate fragment bounds once for spatial culling
			var fragment_bounds := _calculate_bounds(fragment)

			# Subtract each hole (with spatial culling)
			for hole_idx in range(1, polygons.size()):
				# Spatial culling: Skip holes that don't overlap fragment bounds
				if not fragment_bounds.intersects(hole_bounds[hole_idx - 1]):
					continue

				var hole := polygons[hole_idx]
				var next_remaining: Array[PackedVector2Array] = []

				# Subtract hole from each remaining fragment
				for piece in remaining:
					var after_subtract := Geometry2D.clip_polygons(piece, hole)
					next_remaining.append_array(after_subtract)

				remaining = next_remaining

			# Add all surviving fragments
			for final_piece in remaining:
				if final_piece.size() >= 3:  # Valid polygon
					fragments.append(final_piece)

	# If fracturing failed somehow, return original
	if fragments.is_empty():
		push_warning("CutoutDestructionVoronoi: No valid fragments generated, returning original")
		return polygons

	return fragments


## Generates seed points within the polygon bounds using the selected pattern.
func _generate_seed_points(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	# Dispatch to pattern-specific generator
	match pattern:
		SeedPattern.RANDOM:
			return _generate_random_seeds(polygon, bounds, rng)
		SeedPattern.GRID:
			return _generate_grid_seeds(polygon, bounds, rng)
		SeedPattern.RADIAL:
			return _generate_radial_seeds(polygon, bounds, rng)
		SeedPattern.SPIDERWEB:
			return _generate_spiderweb_seeds(polygon, bounds, rng)
		SeedPattern.POISSON_DISK:
			return _generate_poisson_seeds(polygon, bounds, rng)
		_:
			push_error("Unknown seed pattern: %d" % pattern)
			return PackedVector2Array()


## Checks if a point is far enough from all existing points.
func _is_far_enough(point: Vector2, existing_points: PackedVector2Array, min_distance: float) -> bool:
	for p in existing_points:
		if point.distance_to(p) < min_distance:
			return false
	return true


## Computes Delaunay triangulation using Godot's built-in method.
func _delaunay_triangulation(points: PackedVector2Array) -> PackedInt32Array:
	# Godot's Delaunay triangulation
	return Geometry2D.triangulate_delaunay(points)


## Converts Delaunay triangulation to Voronoi cells.
## Uses Delaunay adjacency to optimize clipping - only clips against neighboring seeds.
func _compute_voronoi_cells(seed_points: PackedVector2Array, triangulation: PackedInt32Array, bounds: Rect2) -> Array[PackedVector2Array]:
	var cells: Array[PackedVector2Array] = []
	_debug_voronoi_vertices.clear()

	# Build adjacency map from Delaunay triangulation
	var num_points := seed_points.size()
	var adjacency: Dictionary = {}

	# Initialize adjacency lists
	for i in range(num_points):
		adjacency[i] = []

	# Extract adjacency from triangulation and calculate Voronoi vertices
	# Each triangle defines 3 edges, each edge means two seeds are neighbors
	# The circumcenter of each triangle is a Voronoi vertex
	for i in range(0, triangulation.size(), 3):
		var a := triangulation[i]
		var b := triangulation[i + 1]
		var c := triangulation[i + 2]

		# Calculate circumcenter (Voronoi vertex) for this triangle
		var pa := seed_points[a]
		var pb := seed_points[b]
		var pc := seed_points[c]
		var circumcenter := _calculate_circumcenter(pa, pb, pc)
		if circumcenter != Vector2.INF:
			_debug_voronoi_vertices.append(circumcenter)

		# Add bidirectional adjacency for each edge
		if not adjacency[a].has(b): adjacency[a].append(b)
		if not adjacency[b].has(a): adjacency[b].append(a)

		if not adjacency[b].has(c): adjacency[b].append(c)
		if not adjacency[c].has(b): adjacency[c].append(b)

		if not adjacency[c].has(a): adjacency[c].append(a)
		if not adjacency[a].has(c): adjacency[a].append(c)

	# For each seed point, compute its Voronoi cell using only neighbors
	for i in range(num_points):
		var neighbors: Array = adjacency[i]
		var cell := _compute_voronoi_cell_for_point(i, seed_points, neighbors, bounds)
		if cell.size() >= 3:
			cells.append(cell)

	return cells


## Computes a Voronoi cell for a specific point using perpendicular bisectors.
## Optimized: Only clips against neighboring seeds from Delaunay triangulation.
func _compute_voronoi_cell_for_point(point_idx: int, seed_points: PackedVector2Array, neighbors: Array, bounds: Rect2) -> PackedVector2Array:
	var center := seed_points[point_idx]

	# Start with bounds (no expansion - keeps cells reasonable size)
	var cell_bounds := bounds

	# Build Voronoi cell by intersecting half-planes
	# Start with bounding box
	var cell := PackedVector2Array([
		cell_bounds.position,
		Vector2(cell_bounds.end.x, cell_bounds.position.y),
		cell_bounds.end,
		Vector2(cell_bounds.position.x, cell_bounds.end.y)
	])

	# Only clip against NEIGHBORS from Delaunay triangulation
	# This is the key optimization: typically ~6 neighbors instead of N-1 seeds
	for neighbor_idx in neighbors:
		var other := seed_points[neighbor_idx]
		var midpoint := (center + other) * 0.5
		# Normal points from neighbor toward center
		# This keeps points closer to center than to neighbor
		var normal := (center - other).normalized()

		# Clip cell against this neighbor's perpendicular bisector
		cell = _clip_polygon_to_half_plane(cell, midpoint, normal)

		if cell.size() < 3:
			break  # Cell has been clipped away completely

	return cell


## Clips a polygon against a half-plane defined by a point and normal.
## Keeps the side of the polygon in the direction of the normal.
func _clip_polygon_to_half_plane(polygon: PackedVector2Array, plane_point: Vector2, plane_normal: Vector2) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()

	var clipped := PackedVector2Array()
	var n := polygon.size()

	for i in range(n):
		var current := polygon[i]
		var next := polygon[(i + 1) % n]

		var current_dist := (current - plane_point).dot(plane_normal)
		var next_dist := (next - plane_point).dot(plane_normal)

		var current_inside := current_dist >= 0
		var next_inside := next_dist >= 0

		if current_inside:
			clipped.append(current)

		# If edge crosses the plane, add intersection point
		if current_inside != next_inside:
			var t := current_dist / (current_dist - next_dist)
			var intersection := current.lerp(next, t)
			clipped.append(intersection)

	return clipped


## Clips one polygon to another polygon boundary (Sutherland-Hodgman algorithm).
func _clip_polygon_to_polygon(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	if subject.size() < 3 or clip.size() < 3:
		return PackedVector2Array()

	var output := subject
	var n := clip.size()

	# Clip against each edge of the clipping polygon
	for i in range(n):
		if output.size() < 3:
			break

		var edge_start := clip[i]
		var edge_end := clip[(i + 1) % n]
		var edge_vec := edge_end - edge_start
		var edge_normal := Vector2(-edge_vec.y, edge_vec.x).normalized()

		# Ensure normal points inward (for CW winding, use outward normal)
		# We want to keep points on the "inside" of the edge
		output = _clip_polygon_to_half_plane(output, edge_start, edge_normal)

	return output


## Calculates the bounding rectangle of a polygon.
func _calculate_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_y := polygon[0].y
	var max_y := polygon[0].y

	for p in polygon:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## Calculates the circumcenter of a triangle (equidistant from all 3 vertices).
## Returns Vector2.INF if the triangle is degenerate (collinear points).
func _calculate_circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	# Calculate using the circumcenter formula
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))

	# Check for degenerate triangle (collinear points)
	if abs(d) < 0.0001:
		return Vector2.INF

	var a_sq := a.x * a.x + a.y * a.y
	var b_sq := b.x * b.x + b.y * b.y
	var c_sq := c.x * c.x + c.y * c.y

	var ux := (a_sq * (b.y - c.y) + b_sq * (c.y - a.y) + c_sq * (a.y - b.y)) / d
	var uy := (a_sq * (c.x - b.x) + b_sq * (a.x - c.x) + c_sq * (b.x - a.x)) / d

	return Vector2(ux, uy)


## Checks if a point is inside a polygon using ray casting.
func _is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var n := polygon.size()
	var inside := false

	var p1 := polygon[0]
	for i in range(1, n + 1):
		var p2 := polygon[i % n]

		if point.y > min(p1.y, p2.y):
			if point.y <= max(p1.y, p2.y):
				if point.x <= max(p1.x, p2.x):
					var xinters: float
					if p1.y != p2.y:
						xinters = (point.y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x
					if p1.x == p2.x or point.x <= xinters:
						inside = not inside

		p1 = p2

	return inside


## Pattern-specific seed generation functions

## Generates purely random seed points.
func _generate_random_seeds(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var padded_bounds := bounds.grow(-edge_padding)

	if padded_bounds.size.x <= 0 or padded_bounds.size.y <= 0:
		padded_bounds = bounds

	var min_dist: float = min(padded_bounds.size.x, padded_bounds.size.y) * min_cell_distance
	var max_attempts := fragment_count * 10
	var attempts := 0

	while points.size() < fragment_count and attempts < max_attempts:
		attempts += 1

		var candidate := Vector2(
			rng.randf_range(padded_bounds.position.x, padded_bounds.position.x + padded_bounds.size.x),
			rng.randf_range(padded_bounds.position.y, padded_bounds.position.y + padded_bounds.size.y)
		)

		if _is_point_in_polygon(candidate, polygon):
			if _is_far_enough(candidate, points, min_dist):
				points.append(candidate)

	return points


## Generates grid-based seed points with optional jitter.
func _generate_grid_seeds(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var padded_bounds := bounds.grow(-edge_padding)

	if padded_bounds.size.x <= 0 or padded_bounds.size.y <= 0:
		padded_bounds = bounds

	var min_dist: float = min(padded_bounds.size.x, padded_bounds.size.y) * min_cell_distance
	var cell_size := Vector2(
		padded_bounds.size.x / _grid_cols,
		padded_bounds.size.y / _grid_rows
	)

	for y in range(_grid_rows):
		for x in range(_grid_cols):
			# Grid center with random jitter
			var jitter := Vector2(
				rng.randf_range(-0.5, 0.5) * cell_size.x * _grid_jitter,
				rng.randf_range(-0.5, 0.5) * cell_size.y * _grid_jitter
			)

			var candidate := Vector2(
				padded_bounds.position.x + (x + 0.5) * cell_size.x + jitter.x,
				padded_bounds.position.y + (y + 0.5) * cell_size.y + jitter.y
			)

			if _is_point_in_polygon(candidate, polygon):
				if _is_far_enough(candidate, points, min_dist):
					points.append(candidate)

	return points


## Generates radial seed points in concentric rings.
func _generate_radial_seeds(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = _origin if _origin != Vector2.ZERO else bounds.get_center()
	var min_dist: float = min(bounds.size.x, bounds.size.y) * min_cell_distance

	# Calculate maximum radius (distance to furthest corner)
	var max_radius: float = 0.0
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		max_radius = max(max_radius, center.distance_to(corner))

	var attempted := 0
	var rejected_dist := 0
	var rejected_polygon := 0

	# Distribute seeds across rings
	for ring_idx in range(_ring_count):
		var ring_number: float = ring_idx + 1
		# Use _ring_size as the pixel distance between rings
		var base_radius: float = ring_number * _ring_size

		# Number of seeds in this ring (more seeds in outer rings)
		var seeds_in_ring := maxi(3, roundi(_points_per_ring * ring_number / _ring_count))

		for i in range(seeds_in_ring):
			attempted += 1
			var angle: float = TAU * i / seeds_in_ring

			# Add random variation to radius and angle
			var radius_variation: float = rng.randf_range(-_radial_variation, _radial_variation) * (max_radius / _ring_count)
			var angle_variation: float = rng.randf_range(-_radial_variation, _radial_variation) * (TAU / seeds_in_ring)

			var radius: float = base_radius + radius_variation
			var final_angle: float = angle + angle_variation

			var candidate := center + Vector2(cos(final_angle), sin(final_angle)) * radius

			if not _is_point_in_polygon(candidate, polygon):
				rejected_polygon += 1
				continue

			if not _is_far_enough(candidate, points, min_dist):
				rejected_dist += 1
				continue

			points.append(candidate)

	print("Radial pattern: attempted=%d, accepted=%d, rejected_polygon=%d, rejected_dist=%d, min_dist=%.1f" % [attempted, points.size(), rejected_polygon, rejected_dist, min_dist])
	return points


## Generates spiderweb seed points (radial rays + concentric rings).
func _generate_spiderweb_seeds(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = _origin if _origin != Vector2.ZERO else bounds.get_center()
	var min_dist: float = min(bounds.size.x, bounds.size.y) * min_cell_distance

	# Add center point
	if _is_point_in_polygon(center, polygon):
		points.append(center)

	# Calculate maximum radius
	var max_radius: float = 0.0
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		max_radius = max(max_radius, center.distance_to(corner))

	# Generate rays (spokes)
	var ray_count: int = _points_per_ring

	for ray_idx in range(ray_count):
		var base_angle: float = TAU * ray_idx / ray_count

		# Place seeds along this ray
		for ring_idx in range(1, _ring_count + 1):
			# Use _ring_size as the pixel distance between rings
			var radius: float = ring_idx * _ring_size

			# Add variation
			var angle_variation: float = rng.randf_range(-_radial_variation, _radial_variation) * (TAU / ray_count / 2)
			var radius_variation: float = rng.randf_range(-_radial_variation, _radial_variation) * (max_radius / _ring_count / 2)

			var final_angle: float = base_angle + angle_variation
			var final_radius: float = radius + radius_variation

			var candidate := center + Vector2(cos(final_angle), sin(final_angle)) * final_radius

			if _is_point_in_polygon(candidate, polygon):
				if _is_far_enough(candidate, points, min_dist):
					points.append(candidate)

	return points


## Generates Poisson disk distributed seed points (blue noise).
func _generate_poisson_seeds(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var padded_bounds := bounds.grow(-edge_padding)

	if padded_bounds.size.x <= 0 or padded_bounds.size.y <= 0:
		padded_bounds = bounds

	var min_dist: float = min(padded_bounds.size.x, padded_bounds.size.y) * min_cell_distance
	var max_total_attempts := fragment_count * _poisson_attempts

	var active_list: Array[Vector2] = []

	# Start with random first point
	var first_point := Vector2(
		rng.randf_range(padded_bounds.position.x, padded_bounds.position.x + padded_bounds.size.x),
		rng.randf_range(padded_bounds.position.y, padded_bounds.position.y + padded_bounds.size.y)
	)

	if _is_point_in_polygon(first_point, polygon):
		points.append(first_point)
		active_list.append(first_point)

	var total_attempts := 0

	# Process active list
	while not active_list.is_empty() and points.size() < fragment_count and total_attempts < max_total_attempts:
		# Pick random point from active list
		var idx := rng.randi() % active_list.size()
		var point := active_list[idx]

		var found_valid := false

		# Try to generate points around it
		for _attempt in range(_poisson_attempts):
			total_attempts += 1

			# Generate point in annulus (ring) around current point
			var angle: float = rng.randf() * TAU
			var radius: float = min_dist * (1.0 + rng.randf())

			var candidate := point + Vector2(cos(angle), sin(angle)) * radius

			# Check if in bounds and polygon
			if not padded_bounds.has_point(candidate):
				continue

			if not _is_point_in_polygon(candidate, polygon):
				continue

			# Check distance to all existing points
			if _is_far_enough(candidate, points, min_dist):
				points.append(candidate)
				active_list.append(candidate)
				found_valid = true
				break

		# Remove from active list if no valid points found
		if not found_valid:
			active_list.remove_at(idx)

	return points
