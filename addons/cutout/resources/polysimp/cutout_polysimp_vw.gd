@tool
class_name CutoutPolysimpVW
extends CutoutPolysimpAlgorithm

## Visvalingam-Whyatt polygon simplification algorithm.
##
## This algorithm progressively removes points that form the smallest triangular
## area with their neighbors, preserving the most visually significant points.
## It supports multiple stopping criteria: target proportion, target count, or
## minimum area threshold.
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).

## Stopping criteria for the simplification algorithm.
enum StoppingCriteria {
	PROPORTION, ## Keep a proportion (0.0-1.0) of the original points
	COUNT,      ## Keep a specific number of points
	AREA        ## Remove points forming triangles below an area threshold
}

## The method used to determine when to stop simplifying.
@export var stopping_criteria: StoppingCriteria = StoppingCriteria.AREA:
	set(value):
		stopping_criteria = value
		notify_property_list_changed()
		emit_changed()

## Proportion of original points to keep (0.0-1.0).
## Only used when stopping_criteria is PROPORTION.
var proportion: float = 0.5

## Number of points to keep in the simplified polygon.
## Only used when stopping_criteria is COUNT.
var point_count: int = 50

## Minimum allowed area for triangles formed by neighboring points.
## Points forming smaller triangles will be removed.
## Only used when stopping_criteria is AREA.
var area_threshold: float = 1.0


## Override property list to show only relevant parameters.
func _get_property_list() -> Array:
	var properties := []

	match stopping_criteria:
		StoppingCriteria.PROPORTION:
			properties.append({
				"name": "proportion",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01"
			})
		StoppingCriteria.COUNT:
			properties.append({
				"name": "point_count",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "3,10000,1"
			})
		StoppingCriteria.AREA:
			properties.append({
				"name": "area_threshold",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,100.0,0.1"
			})

	return properties


## Custom setter to emit changed signal.
func _set(property: StringName, value: Variant) -> bool:
	match property:
		"proportion":
			proportion = value
			tolerance = value  # Sync with base class
			emit_changed()
			return true
		"point_count":
			point_count = value
			emit_changed()
			return true
		"area_threshold":
			area_threshold = value
			tolerance = value  # Sync with base class
			emit_changed()
			return true
	return false


## Custom getter for properties.
func _get(property: StringName) -> Variant:
	match property:
		"proportion":
			return proportion
		"point_count":
			return point_count
		"area_threshold":
			return area_threshold
	return null


## Calculates the area of a triangle formed by three points.
## Uses the cross product formula: area = |cross product| / 2
##
## @param p1: First point
## @param p2: Second point (the vertex whose area contribution we're measuring)
## @param p3: Third point
## @return: The absolute area of the triangle
static func _triangle_area(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	# Using cross product: area = |(x1(y2-y3) + x2(y3-y1) + x3(y1-y2))| / 2
	var area := abs((p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y)) / 2.0)
	return area


## Helper class to track point information during simplification.
class PointInfo:
	var index: int          ## Original index in the polygon
	var position: Vector2   ## Position of the point
	var area: float         ## Effective area (triangle with neighbors)
	var removed: bool       ## Whether this point has been removed

	func _init(idx: int, pos: Vector2) -> void:
		index = idx
		position = pos
		area = 0.0
		removed = false


## Simplifies a polygon using the Visvalingam-Whyatt algorithm.
##
## @param polygon: The input polygon to simplify
## @param criteria: The stopping criteria to use
## @param target_value: The value for the stopping criteria (proportion, count, or area threshold)
## @return: The simplified polygon
static func vw_simplify(polygon: PackedVector2Array, criteria: StoppingCriteria, target_value: float) -> PackedVector2Array:
	var point_count := polygon.size()

	if point_count < 3:
		return polygon

	# Initialize point information
	var points: Array[PointInfo] = []
	for i in range(point_count):
		points.append(PointInfo.new(i, polygon[i]))

	# Calculate initial effective areas for all points
	for i in range(point_count):
		var prev_idx := (i - 1 + point_count) % point_count
		var next_idx := (i + 1) % point_count
		points[i].area = _triangle_area(points[prev_idx].position, points[i].position, points[next_idx].position)

	# Determine stopping condition
	var target_remaining: int
	var use_area_threshold := false

	match criteria:
		StoppingCriteria.PROPORTION:
			target_remaining = max(3, int(point_count * target_value))
		StoppingCriteria.COUNT:
			target_remaining = max(3, int(target_value))
		StoppingCriteria.AREA:
			target_remaining = 3  # Minimum viable polygon
			use_area_threshold = true

	var remaining_count := point_count

	# Iteratively remove points with smallest area
	while remaining_count > target_remaining:
		# Find point with minimum area that hasn't been removed
		var min_area := INF
		var min_index := -1

		for i in range(point_count):
			if not points[i].removed and points[i].area < min_area:
				min_area = points[i].area
				min_index = i

		# Check area threshold stopping condition
		if use_area_threshold and min_area > target_value:
			break

		if min_index == -1:
			break

		# Mark point as removed
		points[min_index].removed = true
		remaining_count -= 1

		if remaining_count <= 3:
			break

		# Recalculate areas for neighboring points
		var prev_idx := min_index
		var next_idx := min_index

		# Find previous non-removed point
		for _i in range(point_count):
			prev_idx = (prev_idx - 1 + point_count) % point_count
			if not points[prev_idx].removed:
				break

		# Find next non-removed point
		for _i in range(point_count):
			next_idx = (next_idx + 1) % point_count
			if not points[next_idx].removed:
				break

		# Update areas for previous and next points
		for idx in [prev_idx, next_idx]:
			if points[idx].removed:
				continue

			# Find neighbors of this point
			var prev: int = idx
			for _i in range(point_count):
				prev = (prev - 1 + point_count) % point_count
				if not points[prev].removed:
					break

			var next: int = idx
			for _i in range(point_count):
				next = (next + 1) % point_count
				if not points[next].removed:
					break

			points[idx].area = _triangle_area(points[prev].position, points[idx].position, points[next].position)

	# Build simplified polygon from remaining points
	var simplified := PackedVector2Array()
	for i in range(point_count):
		if not points[i].removed:
			simplified.append(points[i].position)

	return simplified


## Implementation of the abstract _simplify method.
func _simplify(polygon: PackedVector2Array) -> PackedVector2Array:
	var target_value: float

	match stopping_criteria:
		StoppingCriteria.PROPORTION:
			target_value = proportion
		StoppingCriteria.COUNT:
			target_value = float(point_count)
		StoppingCriteria.AREA:
			target_value = area_threshold
		_:
			target_value = 1.0

	return vw_simplify(polygon, stopping_criteria, target_value)
