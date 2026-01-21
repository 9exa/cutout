@tool
class_name CutoutPolysimpRW
extends CutoutPolysimpAlgorithm

## Reumann-Witkam polygon simplification algorithm.
##
## This algorithm uses a "corridor" approach where it creates a strip of width
## epsilon around each line segment. Points within the corridor are removed,
## and points outside become new key points. It's a single-pass algorithm that
## processes points sequentially from a starting index.
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).

## Distance threshold for the corridor width.
## Points within epsilon perpendicular distance from the current line segment
## will be removed. Higher values result in more aggressive simplification.
@export_range(0.0, 10.0, 0.1) var epsilon: float = 1.0:
	set(value):
		epsilon = value
		tolerance = value  # Keep base class tolerance in sync
		emit_changed()

## Starting index for the simplification algorithm.
## The algorithm will begin processing from this point in the polygon.
## This can affect the output since Reumann-Witkam is sensitive to point order.
@export_range(0, 10000, 1) var start_index: int = 0:
	set(value):
		start_index = value
		emit_changed()


## Calculates the perpendicular distance from a point to an infinite line.
## Unlike line segment distance, this projects the point onto the infinite line.
##
## @param point: The point to measure distance from
## @param line_start: A point on the line
## @param line_end: Another point on the line
## @return: The perpendicular distance from the point to the line
static func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec := line_end - line_start
	var line_length_sq := line_vec.length_squared()

	# If line is actually a point
	if line_length_sq == 0.0:
		return point.distance_to(line_start)

	# Calculate perpendicular distance using cross product
	# Distance = |cross product| / |line length|
	var point_vec := point - line_start
	var cross := line_vec.x * point_vec.y - line_vec.y * point_vec.x

	return abs(cross) / sqrt(line_length_sq)


## Simplifies a polygon using the Reumann-Witkam algorithm.
##
## @param polygon: The input polygon to simplify
## @param epsilon: Distance threshold for the corridor
## @param start_idx: Index to start simplification from
## @return: The simplified polygon
static func rw_simplify(polygon: PackedVector2Array, epsilon: float, start_idx: int = 0) -> PackedVector2Array:
	var point_count := polygon.size()

	if point_count < 3:
		return polygon

	# Ensure start_index is valid
	start_idx = start_idx % point_count

	var simplified := PackedVector2Array()

	# Start with the initial point
	var key_index := start_idx
	simplified.append(polygon[key_index])

	# Process all points
	var processed := 0
	while processed < point_count:
		# Find the next candidate point (skip the current key point)
		var next_index := (key_index + 1) % point_count

		# If we've looped back to start, we're done
		if next_index == start_idx and processed > 0:
			break

		# The line is defined by the current key point and the next point
		var line_start := polygon[key_index]
		var line_point := polygon[next_index]

		# Find the farthest point we can reach while staying within the corridor
		var last_valid_index := next_index
		var test_index := (next_index + 1) % point_count

		# Keep extending the corridor while points are within epsilon distance
		while test_index != start_idx and processed + (test_index - next_index + point_count) % point_count < point_count:
			var test_point := polygon[test_index]
			var distance := _point_to_line_distance(test_point, line_start, line_point)

			if distance <= epsilon:
				# Point is within corridor, can potentially skip it
				last_valid_index = test_index
				test_index = (test_index + 1) % point_count
			else:
				# Point is outside corridor, stop here
				break

		# Move to the next key point (the last point that was outside the corridor,
		# or the last valid point we tested)
		var new_key_index := (last_valid_index + 1) % point_count

		# If the test stopped due to a point outside the corridor, use that point
		if test_index != start_idx and test_index != (last_valid_index + 1) % point_count:
			new_key_index = test_index

		# Avoid infinite loops
		if new_key_index == key_index:
			new_key_index = (key_index + 1) % point_count

		# Update processed count
		var points_skipped := (new_key_index - key_index + point_count) % point_count
		processed += points_skipped

		# Add the new key point if it's not the start
		if new_key_index != start_idx or processed < point_count:
			simplified.append(polygon[new_key_index])
			key_index = new_key_index
		else:
			break

		# Safety check to prevent infinite loops
		if simplified.size() >= point_count:
			break

	# Ensure we don't duplicate the start point for closed polygons
	if simplified.size() > 1 and simplified[0].is_equal_approx(simplified[simplified.size() - 1]):
		simplified.resize(simplified.size() - 1)

	return simplified


## Implementation of the abstract _simplify method.
func _simplify(polygon: PackedVector2Array) -> PackedVector2Array:
	return rw_simplify(polygon, epsilon, start_index)
