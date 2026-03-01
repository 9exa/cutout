@tool
class_name CutoutDestructionSlices
extends CutoutDestructionAlgorithm

## Slice-based destruction algorithm (single or multiple cuts).
##
## Creates cuts through a polygon using one of three modes:
## - Single mode: One clean cut (sword slash, laser beam)
## - Pattern mode: Multiple cuts in various patterns (radial, parallel, grid, chaotic)
## - Manual mode: User-defined array of SegmentShape2D resources
##
## Useful for:
## - Single cuts: Sword slashes, laser beams, clean bisections
## - Shattered glass (multiple radial cuts from impact point)
## - Chopped materials (wood planks with parallel cuts)
## - Grid destruction (perpendicular cuts)
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).


## Mode for generating slice lines.
enum SliceMode {
	SINGLE,  ## Single cut line (replaces CutoutDestructionSlice)
	PATTERN,  ## Generate random cut lines based on slice_count
	MANUAL   ## Use user-defined SegmentShape2D array
}

## Random slice generation pattern.
enum Pattern {
	RADIAL,      ## Lines radiate from center (star pattern)
	PARALLEL,    ## Lines are parallel (wood grain, planks)
	GRID,        ## Perpendicular horizontal and vertical lines (grid, tiles)
	CHAOTIC      ## Completely random lines (natural shattering)
}


## Mode for generating slice lines
@export var mode: SliceMode = SliceMode.PATTERN:
	set(value):
		mode = value
		notify_property_list_changed()
		emit_changed()

const PARALLEL_PATTERN_OPTIMIZED_ANGLE_RAND_THRESH = 0.4

# Mode-specific properties (exposed via _get_property_list)
# Single mode properties
var _line_start: Vector2 = Vector2(-100, 0)
var _line_end: Vector2 = Vector2(100, 0)
# Pattern mode properties
var _slice_count: int = 3
var _pattern: Pattern = Pattern.CHAOTIC
var _parallel_angle: float = 0.0
var _parallel_angle_rand: float = 0.0  # Random angle variation for parallel lines (0-1 range)
var _origin: Vector2 = Vector2.ZERO  # Absolute position in polygon coordinate space (Vector2.ZERO = auto-center)
var _radial_randomness: float = 0.0  # 0-1 range for angle variation
var _h_start: float = 0.0  # Absolute X position for first vertical line
var _v_start: float = 0.0  # Absolute Y position for first horizontal line
var _h_slices: int = 3  # Number of vertical lines
var _v_slices: int = 3  # Number of horizontal lines
var _h_random: float = 0.0  # Random jitter for vertical lines (0-1 range)
var _v_random: float = 0.0  # Random jitter for horizontal lines (0-1 range)
var _h_angle_rand: float = 0.0  # Random angle variation for vertical lines (0-1 range)
var _v_angle_rand: float = 0.0  # Random angle variation for horizontal lines (0-1 range)
var _manual_slices: Array[SegmentShape2D] = []


## Dynamically expose only mode-relevant properties in the inspector.
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	if mode == SliceMode.SINGLE:
		properties.append({
			"name": "line_start",
			"type": TYPE_VECTOR2,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			"name": "line_end",
			"type": TYPE_VECTOR2,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif mode == SliceMode.PATTERN:
		properties.append({
			"name": "slice_count",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,20,1",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			"name": "pattern",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Radial,Parallel,Grid,Chaotic",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if _pattern == Pattern.RADIAL:
			properties.append({
				"name": "origin",
				"type": TYPE_VECTOR2,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "radial_randomness",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		if _pattern == Pattern.PARALLEL:
			properties.append({
				"name": "parallel_angle",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0,360,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "parallel_angle_rand",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

		if _pattern == Pattern.GRID:
			properties.append({
				"name": "h_start",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "v_start",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "h_slices",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,20,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "v_slices",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,20,1",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "h_random",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "v_random",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "h_angle_rand",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			properties.append({
				"name": "v_angle_rand",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	else:  # MANUAL mode
		properties.append({
			"name": "manual_slices",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":SegmentShape2D",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties


## Get property values for mode-specific parameters.
func _get(property: StringName):
	match property:
		"line_start": return _line_start
		"line_end": return _line_end
		"slice_count": return _slice_count
		"pattern": return _pattern
		"parallel_angle": return _parallel_angle
		"parallel_angle_rand": return _parallel_angle_rand
		"origin": return _origin
		"radial_randomness": return _radial_randomness
		"h_start": return _h_start
		"v_start": return _v_start
		"h_slices": return _h_slices
		"v_slices": return _v_slices
		"h_random": return _h_random
		"v_random": return _v_random
		"h_angle_rand": return _h_angle_rand
		"v_angle_rand": return _v_angle_rand
		"manual_slices": return _manual_slices
	return null


## Set property values for mode-specific parameters.
func _set(property: StringName, value) -> bool:
	match property:
		"line_start":
			_line_start = value
			emit_changed()
			return true
		"line_end":
			_line_end = value
			emit_changed()
			return true
		"slice_count":
			_slice_count = value
			emit_changed()
			return true
		"pattern":
			_pattern = value
			notify_property_list_changed()
			emit_changed()
			return true
		"parallel_angle":
			_parallel_angle = value
			emit_changed()
			return true
		"parallel_angle_rand":
			_parallel_angle_rand = value
			emit_changed()
			return true
		"origin":
			_origin = value
			emit_changed()
			return true
		"radial_randomness":
			_radial_randomness = value
			emit_changed()
			return true
		"h_start":
			_h_start = value
			emit_changed()
			return true
		"v_start":
			_v_start = value
			emit_changed()
			return true
		"h_slices":
			_h_slices = value
			emit_changed()
			return true
		"v_slices":
			_v_slices = value
			emit_changed()
			return true
		"h_random":
			_h_random = value
			emit_changed()
			return true
		"v_random":
			_v_random = value
			emit_changed()
			return true
		"h_angle_rand":
			_h_angle_rand = value
			emit_changed()
			return true
		"v_angle_rand":
			_v_angle_rand = value
			emit_changed()
			return true
		"manual_slices":
			_manual_slices = value
			emit_changed()
			return true

	return false


## Implementation of multi-slice fracture algorithm.
## Delegates the entire pipeline (segment generation + slicing + holes) to Rust.
func _fracture(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if mode == SliceMode.SINGLE:
		# Single cut mode - replaces CutoutDestructionSlice
		if _line_start.distance_to(_line_end) < 0.001:
			push_warning("CutoutDestructionSlices: Line start and end are too close")
			return polygons

		var fragments := CutoutDestructionProcessor.fracture_slice(
			polygons,
			_line_start,
			_line_end
		)

		if fragments.is_empty():
			push_warning("CutoutDestructionSlices: Line did not intersect polygon")
			return polygons

		return fragments
	elif mode == SliceMode.PATTERN:
		# Call pattern-specific Rust functions to avoid parameter limit
		match _pattern:
			Pattern.RADIAL:
				return CutoutDestructionProcessor.fracture_slices_radial(
					polygons,
					seed,
					_slice_count,
					_origin,
					_radial_randomness
				)
			Pattern.PARALLEL:
				# Special case for parallel with low randomness
				if _parallel_angle_rand < PARALLEL_PATTERN_OPTIMIZED_ANGLE_RAND_THRESH:
					return CutoutDestructionProcessor.fracture_slices_parallel_optimized(
						polygons,
						seed,
						_slice_count,
						_parallel_angle,
						_parallel_angle_rand
					)
				return CutoutDestructionProcessor.fracture_slices_parallel(
					polygons,
					seed,
					_slice_count,
					_parallel_angle,
					_parallel_angle_rand
				)
			Pattern.GRID:
				return CutoutDestructionProcessor.fracture_slices_grid(
					polygons,
					seed,
					_h_start,
					_v_start,
					_h_slices,
					_v_slices,
					_h_random,
					_v_random,
					_h_angle_rand,
					_v_angle_rand
				)
			Pattern.CHAOTIC:
				return CutoutDestructionProcessor.fracture_slices_chaotic(
					polygons,
					seed,
					_slice_count
				)
			_:
				push_warning("CutoutDestructionSlices: Unknown pattern type")
				return polygons
	else:  # MANUAL mode
		if _manual_slices.is_empty():
			push_warning("CutoutDestructionSlices: No manual slices defined")
			return polygons

		# Encode manual segments for Rust
		var encoded_segments: Array[PackedVector2Array] = []
		for segment in _manual_slices:
			if segment:
				encoded_segments.append(PackedVector2Array([segment.a, segment.b]))

		if encoded_segments.is_empty():
			push_warning("CutoutDestructionSlices: No valid manual slices")
			return polygons

		return CutoutDestructionProcessor.fracture_slices_manual(polygons, encoded_segments)
