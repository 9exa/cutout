@tool
class_name CutoutDestructionSlices
extends CutoutDestructionAlgorithm

## Multi-slice destruction algorithm.
##
## Creates multiple cuts through a polygon using either:
## - Automatic mode: Random lines based on slice_count
## - Manual mode: User-defined array of SegmentShape2D resources
##
## Useful for:
## - Shattered glass (multiple radial cuts from impact point)
## - Chopped materials (wood planks with parallel cuts)
## - Grid destruction (perpendicular cuts)
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).


## Mode for generating slice lines.
enum SliceMode {
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

	if mode == SliceMode.PATTERN:
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
	print("setting property ", property, " to ", value)
	match property:
		"slice_count":
			_slice_count = value
			emit_changed()
			return true
		"pattern":
			_pattern = value
			print("setting random pattern to ", value)
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
func _fracture(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Extract outer polygon and holes
	var outer_polygon := polygons[0]
	var holes: Array[PackedVector2Array] = []
	if polygons.size() > 1:
		holes.assign(polygons.slice(1))

	# Generate or collect slice segments
	var slice_segments: Array[SegmentShape2D] = []

	if mode == SliceMode.PATTERN:
		print("_pattern: ", _pattern)
		if _pattern == Pattern.PARALLEL and _parallel_angle_rand < PARALLEL_PATTERN_OPTIMIZED_ANGLE_RAND_THRESH:
			# Use optimized path for parallel slices with low randomness
			return _fracture_parallel_optimized(polygons, rng)
		slice_segments = _generate_random_slices(outer_polygon, rng)
	else:  # MANUAL mode
		slice_segments = _manual_slices.duplicate()

	if slice_segments.is_empty():
		push_warning("CutoutDestructionSlices: No slices to apply")
		return polygons

	# Apply slices sequentially to all fragments (only outer polygon)
	# Start with the outer polygon as a single fragment
	var current_fragments: Array[Array] = [[outer_polygon]]

	for segment in slice_segments:
		if not segment:
			continue

		var next_fragments: Array[Array] = []

		for fragment_polygons in current_fragments:
			# Apply this slice to this fragment
			var f_polygons: Array[PackedVector2Array]
			f_polygons.assign(fragment_polygons)
			var result := CutoutGeometryUtils.bisect_polygon(
				f_polygons,
				segment.a,
				segment.b
			)

			# Add both sides as new fragments
			# result[0] = left polygons, result[1] = right polygons
			for left_poly in result[0]:
				if left_poly.size() >= 3:
					next_fragments.append([left_poly])

			for right_poly in result[1]:
				if right_poly.size() >= 3:
					next_fragments.append([right_poly])

		# If no fragments were created, keep the current ones
		if next_fragments.is_empty():
			next_fragments = current_fragments

		current_fragments = next_fragments

	# Extract final polygons
	var final_fragments: Array[PackedVector2Array] = []
	for fragment_polygons in current_fragments:
		if fragment_polygons[0].size() >= 3:
			final_fragments.append(fragment_polygons[0])

	# Subtract holes from all fragments
	final_fragments = _subtract_holes_from_fragments(final_fragments, holes)

	return final_fragments


## Generate random slice lines based on the selected pattern.
func _generate_random_slices(polygon: PackedVector2Array, rng: RandomNumberGenerator) -> Array[SegmentShape2D]:
	var slices: Array[SegmentShape2D] = []
	var bounds := _calculate_bounds(polygon)
	var center := bounds.get_center()
	var max_extent := max(bounds.size.x, bounds.size.y)

	match _pattern:
		Pattern.RADIAL:
			# Lines radiate from origin at angles with optional randomness
			# Use custom origin if specified, otherwise use polygon center
			var origin := _origin if _origin != Vector2.ZERO else center

			var angle_step := TAU / _slice_count
			for i in range(_slice_count):
				var base_angle := i * angle_step

				# Add randomness to angle if specified
				var angle := base_angle
				if _radial_randomness > 0.0:
					var max_deviation := angle_step * _radial_randomness * 0.5
					angle += rng.randf_range(-max_deviation, max_deviation)

				var dir := Vector2(cos(angle), sin(angle))
				var segment := SegmentShape2D.new()
				segment.a = origin - dir * max_extent
				segment.b = origin + dir * max_extent
				slices.append(segment)

		Pattern.PARALLEL:
			# Parallel lines at regular intervals
			var base_angle := deg_to_rad(_parallel_angle)
			var spacing: float = max_extent * 2.0 / (_slice_count + 1)

			for i in range(1, _slice_count + 1):
				var angle := base_angle

				# Add randomness to angle if specified
				if _parallel_angle_rand > 0.0:
					var max_angle_deviation := deg_to_rad(45.0) * _parallel_angle_rand  # Up to 45 degrees at max randomness
					angle += rng.randf_range(-max_angle_deviation, max_angle_deviation)

				var dir := Vector2(cos(angle), sin(angle))
				var perp := Vector2(-dir.y, dir.x)
				var offset: Vector2 = perp * (i * spacing - max_extent)
				var segment := SegmentShape2D.new()
				segment.a = center + offset - dir * max_extent
				segment.b = center + offset + dir * max_extent
				slices.append(segment)

		Pattern.GRID:
			# Perpendicular horizontal and vertical lines
			# Calculate spacing based on slice count
			var h_spacing := bounds.size.x / (_h_slices + 1)
			var v_spacing := bounds.size.y / (_v_slices + 1)

			# Generate vertical lines (perpendicular to X-axis, base angle = 90 degrees)
			for i in range(_h_slices):
				var x := _h_start + (i + 1) * h_spacing
				var actual_x := x

				# Apply position jitter
				if _h_random > 0.0:
					var max_jitter := h_spacing * _h_random * 0.5
					actual_x += rng.randf_range(-max_jitter, max_jitter)

				# Base angle is 90 degrees (vertical line)
				var angle := deg_to_rad(90.0)

				# Apply angle randomness
				if _h_angle_rand > 0.0:
					var max_angle_deviation := deg_to_rad(45.0) * _h_angle_rand
					angle += rng.randf_range(-max_angle_deviation, max_angle_deviation)

				var dir := Vector2(cos(angle), sin(angle))
				var line_center := Vector2(actual_x, center.y)

				var segment := SegmentShape2D.new()
				segment.a = line_center - dir * max_extent
				segment.b = line_center + dir * max_extent
				slices.append(segment)

			# Generate horizontal lines (perpendicular to Y-axis, base angle = 0 degrees)
			for i in range(_v_slices):
				var y := _v_start + (i + 1) * v_spacing
				var actual_y := y

				# Apply position jitter
				if _v_random > 0.0:
					var max_jitter := v_spacing * _v_random * 0.5
					actual_y += rng.randf_range(-max_jitter, max_jitter)

				# Base angle is 0 degrees (horizontal line)
				var angle := deg_to_rad(0.0)

				# Apply angle randomness
				if _v_angle_rand > 0.0:
					var max_angle_deviation := deg_to_rad(45.0) * _v_angle_rand
					angle += rng.randf_range(-max_angle_deviation, max_angle_deviation)

				var dir := Vector2(cos(angle), sin(angle))
				var line_center := Vector2(center.x, actual_y)

				var segment := SegmentShape2D.new()
				segment.a = line_center - dir * max_extent
				segment.b = line_center + dir * max_extent
				slices.append(segment)

		Pattern.CHAOTIC:
			# Completely random lines
			for i in range(_slice_count):
				var angle := rng.randf() * TAU
				var dir := Vector2(cos(angle), sin(angle))
				var offset := Vector2(
					rng.randf_range(-max_extent * 0.5, max_extent * 0.5),
					rng.randf_range(-max_extent * 0.5, max_extent * 0.5)
				)
				var segment := SegmentShape2D.new()
				segment.a = center + offset - dir * max_extent
				segment.b = center + offset + dir * max_extent
				slices.append(segment)

	return slices


# # Optimized generation of parallel slices without randomness or perpemdicular offset
# func _fracture_parrallel_no_rand_angle(polygon: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
# 	var slices: Array[PackedVector2Array] = []
# 	var bounds := _calculate_bounds(polygon[0])
# 	var center := bounds.get_center()
# 	var max_extent := max(bounds.size.x, bounds.size.y)
#
# 	var base_angle := deg_to_rad(_parallel_angle)
# 	var spacing: float = max_extent * 2.0 / (_slice_count + 1)
# 	var dir := Vector2(cos(base_angle), sin(base_angle))
# 	var perp := Vector2(-dir.y, dir.x)
#
# 	# keep track of the remaining polygons to slice
# 	var remaining_polygons: Array[PackedVector2Array] = polygon
# 	var output_polygons: Array[PackedVector2Array] = []
#
# 	# Keep future polygons sorted by their minimum project along the perpendicular direction
# 	var min_projs: Array[float]
# 	var max_projs: Array[float]
# 	min_projs.assign(polygon.map(_min_along_frontier.bind(perp)))
# 	max_projs.assign(polygon.map(_max_along_frontier.bind(perp)))
#
# 	var center_proj = center.dot(perp)
#
# 	for i in range(1, _slice_count + 1):
# 		var offset: Vector2 = perp * (i * spacing - max_extent)
# 		var segment := SegmentShape2D.new()
# 		segment.a = center + offset - dir * max_extent
# 		segment.b = center + offset + dir * max_extent
#
# 		var slice := segment
# 		var slice_proj = center_proj + (i * spacing - max_extent)
#
# 		var new_min_projs: Array[float] = []
# 		var new_max_projs: Array[float] = []
# 		var new_remaining_polygons: Array[PackedVector2Array] = []
#
# 		for j in range(remaining_polygons.size()):
# 			if min_projs[j] > slice_proj:
# 				# Polygon is entirely on one side of the slice, keep it for next round
# 				new_min_projs.append(min_projs[j])
# 				new_max_projs.append(max_projs[j])
# 				new_remaining_polygons.append(remaining_polygons[j])
# 				continue
# 			elif max_projs[j] < slice_proj:
# 				# Polygon is entirely on the other side of the slice, output it
# 				output_polygons.append(remaining_polygons[j])
# 				continue
# 			else:
# 				# Polygon intersects the slice, bisect it
# 				var to_bisect: Array[PackedVector2Array]
# 				to_bisect.append(remaining_polygons[j])
# 				var result := CutoutGeometryUtils.bisect_polygon(
# 					to_bisect,
# 					slice.a,
# 					slice.b
# 				)
#
# 				# Process both left and right sides
# 				for result_polygon in result[0]:  # Left side
# 					if result_polygon.size() >= 3:
# 						var min_proj = _min_along_frontier(result_polygon, perp)
# 						var max_proj = _max_along_frontier(result_polygon, perp)
#
# 						new_min_projs.append(min_proj)
# 						new_max_projs.append(max_proj)
# 						new_remaining_polygons.append(result_polygon)
#
# 				for result_polygon in result[1]:  # Right side
# 					if result_polygon.size() >= 3:
# 						var min_proj = _min_along_frontier(result_polygon, perp)
# 						var max_proj = _max_along_frontier(result_polygon, perp)
#
# 						new_min_projs.append(min_proj)
# 						new_max_projs.append(max_proj)
# 						new_remaining_polygons.append(result_polygon)
#
# 		min_projs = new_min_projs
# 		max_projs = new_max_projs
# 		remaining_polygons = new_remaining_polygons
#
# 	output_polygons.append_array(remaining_polygons)
# 	return output_polygons


# Optimized generation of parallel slices with low randomness
func _fracture_parallel_optimized(polygons: Array[PackedVector2Array], rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	print("Using optimized parallel low-random-angle fracture")

	# Extract outer polygon and holes
	var outer_polygon := polygons[0]
	var holes: Array[PackedVector2Array] = []
	if polygons.size() > 1:
		holes.assign(polygons.slice(1))

	var bounds := _calculate_bounds(outer_polygon)
	var center := bounds.get_center()
	var max_extent := max(bounds.size.x, bounds.size.y)

	var base_angle := deg_to_rad(_parallel_angle)
	var spacing: float = max_extent * 2.0 / (_slice_count + 1)

	# Maximum angle deviation in radians
	var max_angle_deviation := deg_to_rad(45.0) * _parallel_angle_rand if _parallel_angle_rand > 0.0 else 0.0

	# Base direction and perpendicular
	var base_dir := Vector2(cos(base_angle), sin(base_angle))
	var base_perp := Vector2(-base_dir.y, base_dir.x)

	# Keep track of remaining polygons to slice (only outer polygon)
	var remaining_polygons: Array[PackedVector2Array] = [outer_polygon]
	var output_polygons: Array[PackedVector2Array] = []

	# Store min/max projections for each polygon
	# We use conservative bounds by considering the angle variation
	var min_projs: Array[float] = []
	var max_projs: Array[float] = []

	# Initialize with conservative projections for the outer polygon only
	var conservative_bounds := _calculate_conservative_projection_bounds(
		outer_polygon, base_perp, max_angle_deviation
	)
	min_projs.append(conservative_bounds[0])
	max_projs.append(conservative_bounds[1])

	var center_proj = center.dot(base_perp)

	for i in range(1, _slice_count + 1):
		# Generate slice with potential angle randomness
		var angle := base_angle
		if _parallel_angle_rand > 0.0:
			angle += rng.randf_range(-max_angle_deviation, max_angle_deviation)

		var dir := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-dir.y, dir.x)
		var offset: Vector2 = perp * (i * spacing - max_extent)

		var segment := SegmentShape2D.new()
		segment.a = center + offset - dir * max_extent
		segment.b = center + offset + dir * max_extent

		var slice_proj = center_proj + (i * spacing - max_extent)

		# Use a slightly expanded slice projection range to account for angle variation
		var slice_proj_min = slice_proj - abs(sin(max_angle_deviation)) * max_extent * 0.1
		var slice_proj_max = slice_proj + abs(sin(max_angle_deviation)) * max_extent * 0.1

		var new_min_projs: Array[float] = []
		var new_max_projs: Array[float] = []
		var new_remaining_polygons: Array[PackedVector2Array] = []

		for j in range(remaining_polygons.size()):
			if min_projs[j] > slice_proj_max:
				# Polygon is entirely on one side of the slice, keep it for next round
				new_min_projs.append(min_projs[j])
				new_max_projs.append(max_projs[j])
				new_remaining_polygons.append(remaining_polygons[j])
				continue
			elif max_projs[j] < slice_proj_min:
				# Polygon is entirely on the other side of the slice, output it
				output_polygons.append(remaining_polygons[j])
				continue
			else:
				# Polygon might intersect the slice, bisect it
				var to_bisect: Array[PackedVector2Array]
				to_bisect.append(remaining_polygons[j])
				var result := CutoutGeometryUtils.bisect_polygon(
					to_bisect,
					segment.a,
					segment.b
				)

				# Process both left and right sides
				for result_polygon in result[0]:  # Left side
					if result_polygon.size() >= 3:
						var result_conservative_bounds := _calculate_conservative_projection_bounds(
							result_polygon, base_perp, max_angle_deviation
						)
						new_min_projs.append(result_conservative_bounds[0])
						new_max_projs.append(result_conservative_bounds[1])
						new_remaining_polygons.append(result_polygon)

				for result_polygon in result[1]:  # Right side
					if result_polygon.size() >= 3:
						var result_conservative_bounds := _calculate_conservative_projection_bounds(
							result_polygon, base_perp, max_angle_deviation
						)
						new_min_projs.append(result_conservative_bounds[0])
						new_max_projs.append(result_conservative_bounds[1])
						new_remaining_polygons.append(result_polygon)

		min_projs = new_min_projs
		max_projs = new_max_projs
		remaining_polygons = new_remaining_polygons

	output_polygons.append_array(remaining_polygons)

	# Subtract holes from all fragments
	output_polygons = _subtract_holes_from_fragments(output_polygons, holes)

	return output_polygons


# Calculate conservative projection bounds accounting for angle variation
func _calculate_conservative_projection_bounds(
	polygon: PackedVector2Array,
	base_perp: Vector2,
	max_angle_deviation: float
) -> Array:
	if max_angle_deviation == 0.0:
		# No angle variation, use exact projections
		var min_proj = _min_along_frontier(polygon, base_perp)
		var max_proj = _max_along_frontier(polygon, base_perp)
		return [min_proj, max_proj]

	# With angle variation, we need to consider the range of possible perpendiculars
	# Conservative approach: expand bounds by maximum possible deviation
	var min_proj = INF
	var max_proj = -INF

	# Test at base angle and extremes
	var test_angles = [
		0.0,  # Base angle
		-max_angle_deviation,  # Minimum angle
		max_angle_deviation   # Maximum angle
	]

	for angle_offset in test_angles:
		var test_perp = base_perp.rotated(angle_offset)
		for point in polygon:
			var proj = point.dot(test_perp)
			min_proj = min(min_proj, proj)
			max_proj = max(max_proj, proj)

	return [min_proj, max_proj]


# How far the minimum point of a point set is along a given direction 
func _min_along_frontier(points: PackedVector2Array, dir: Vector2) -> float:
	var min_proj := points[0].dot(dir)
	for i in range(1, len(points)):
		var proj := points[i].dot(dir)
		min_proj = min(min_proj, proj)
	return min_proj

# How far the maximum point of a point set is along a given direction 
func _max_along_frontier(points: PackedVector2Array, dir: Vector2) -> float:
	var max_proj := points[0].dot(dir)
	for i in range(1, len(points)):
		var proj := points[i].dot(dir)
		max_proj = max(max_proj, proj)
	return max_proj

## Calculate bounding rectangle of a polygon.
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


## Subtract holes from fragments using Clipper library.
## Returns array of fragments with holes removed.
func _subtract_holes_from_fragments(
	fragments: Array[PackedVector2Array],
	holes: Array[PackedVector2Array]
) -> Array[PackedVector2Array]:
	if holes.is_empty():
		return fragments

	var result: Array[PackedVector2Array] = []

	# Precompute hole bounding boxes for spatial optimization
	var hole_bounds: Array[Rect2] = []
	for hole in holes:
		hole_bounds.append(_calculate_bounds(hole))

	for fragment in fragments:
		if fragment.size() < 3:
			continue

		var fragment_bounds := _calculate_bounds(fragment)
		var remaining := [fragment]

		# Subtract each hole that might intersect this fragment
		for i in range(holes.size()):
			var hole := holes[i]

			# Spatial cull: Skip if hole doesn't overlap fragment bounds
			if not fragment_bounds.intersects(hole_bounds[i]):
				continue

			var next_remaining: Array[PackedVector2Array] = []

			# Subtract hole from each remaining fragment piece
			for piece in remaining:
				var after_subtract := Geometry2D.clip_polygons(piece, hole)
				next_remaining.append_array(after_subtract)

			remaining = next_remaining

			# Early exit if nothing remains
			if remaining.is_empty():
				break

		# Add all remaining pieces to result
		result.append_array(remaining)

	return result
