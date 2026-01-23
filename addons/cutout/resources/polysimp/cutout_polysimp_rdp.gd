@tool
class_name CutoutPolysimpRDP
extends CutoutPolysimpAlgorithm

## Ramer-Douglas-Peucker polygon simplification algorithm.
##
## This algorithm recursively simplifies a polygon by removing points that
## contribute less than a specified threshold (epsilon) to the shape. It works
## by finding the point with maximum perpendicular distance from the line
## segment between the first and last points, and recursively simplifying
## the resulting segments if the distance exceeds epsilon.
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).

## Distance threshold for point removal.
## Points with perpendicular distance less than epsilon from the simplified
## line segment will be removed. Higher values result in more aggressive
## simplification (fewer points).
@export_range(0.0, 1000.0, 0.01, "exp") var epsilon: float = 1.0:
	set(value):
		epsilon = value
		emit_changed()


## Calculates the perpendicular distance from a point to a line segment.
##
## @param point: The point to measure distance from
## @param line_start: Start point of the line segment
## @param line_end: End point of the line segment
## @return: The perpendicular distance from the point to the line segment
static func _perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec := line_end - line_start
	var line_length_sq := line_vec.length_squared()

	# If line segment is actually a point
	if line_length_sq == 0.0:
		return point.distance_to(line_start)

	# Calculate perpendicular distance using cross product
	# Distance = |cross product| / |line length|
	var point_vec := point - line_start
	var cross := line_vec.x * point_vec.y - line_vec.y * point_vec.x

	return abs(cross) / sqrt(line_length_sq)


## Recursively simplifies a polygon segment using the RDP algorithm.
##
## @param points: The full array of points
## @param start_index: Start index of the segment to simplify
## @param end_index: End index of the segment to simplify
## @param epsilon: Distance threshold for simplification
## @param keep_mask: Array marking which points to keep (modified in place)
static func _rdp_recursive(points: PackedVector2Array, start_index: int, end_index: int, epsilon: float, keep_mask: Array) -> void:
	if end_index <= start_index + 1:
		return

	# Find the point with maximum distance from the line segment
	var max_distance := 0.0
	var max_index := start_index

	var line_start := points[start_index]
	var line_end := points[end_index]

	for i in range(start_index + 1, end_index):
		var distance := _perpendicular_distance(points[i], line_start, line_end)
		if distance > max_distance:
			max_distance = distance
			max_index = i

	# If max distance is greater than epsilon, split and recurse
	if max_distance > epsilon:
		keep_mask[max_index] = true
		_rdp_recursive(points, start_index, max_index, epsilon, keep_mask)
		_rdp_recursive(points, max_index, end_index, epsilon, keep_mask)


## Simplifies a polygon using the Ramer-Douglas-Peucker algorithm.
##
## @param polygon: The input polygon to simplify
## @param epsilon: Distance threshold for simplification
## @return: The simplified polygon
static func rdp_simplify(polygon: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var point_count := polygon.size()

	if point_count < 3:
		return polygon

	# Initialize keep mask - always keep first and last points
	var keep_mask: Array = []
	keep_mask.resize(point_count)
	keep_mask.fill(false)
	keep_mask[0] = true
	keep_mask[point_count - 1] = true

	# Run recursive simplification
	_rdp_recursive(polygon, 0, point_count - 1, epsilon, keep_mask)

	# Build simplified polygon from kept points
	var simplified := PackedVector2Array()
	for i in range(point_count):
		if keep_mask[i]:
			simplified.append(polygon[i])

	return simplified


## Implementation of the abstract _simplify method.
func _simplify(polygon: PackedVector2Array) -> PackedVector2Array:
	return rdp_simplify(polygon, epsilon)
