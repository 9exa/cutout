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