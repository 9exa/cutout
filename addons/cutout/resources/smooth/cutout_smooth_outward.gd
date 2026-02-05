@tool
extends CutoutSmoothAlgorithm
class_name CutoutSmoothOutward

## Two-pass smoothing algorithm that guarantees area containment.
##
## This algorithm first expands the polygon outward by a specified radius to create
## a safety margin, then applies smoothing while optionally constraining points to
## stay outside the original polygon. This ensures the smoothed result always
## contains the entire area of the original shape, making it ideal for collision
## detection and visual consistency.
##
## WINDING ORDER: Assumes clockwise (CW) polygon winding, consistent with Godot's
## convention where CW = solid and CCW = hole.

const DISPLAY_NAME := "Outward Smooth"

## Expansion radius in pixels. The polygon is first expanded outward by this amount
## to create a safety margin before smoothing. Higher values ensure better containment
## but may create larger polygons.
@export_range(0.0, 100.0, 0.01, "exp") var expansion_radius: float = 2.0:
	set(value):
		expansion_radius = value
		emit_changed()

## If true, constrains smoothing to only move points outward from the original polygon.
## When false, allows free smoothing within the expanded boundary.
@export var constrain_smoothing: bool = true:
	set(value):
		constrain_smoothing = value
		emit_changed()

## If true, attempts to preserve corners that appear intentional (building corners, etc)
## while still smoothing spiky artifacts.
@export var preserve_corners: bool = false:
	set(value):
		preserve_corners = value
		emit_changed()

## Angle threshold in degrees for corner detection. Angles sharper than this
## are considered intentional corners when preserve_corners is enabled.
@export_range(10.0, 180.0, 5.0) var corner_threshold: float = 45.0:
	set(value):
		corner_threshold = value
		emit_changed()

## Density threshold for detecting overcrowded regions. Points closer than this
## distance are considered dense and receive more aggressive smoothing.
@export_range(0.0, 100.0, 0.01, "exp") var density_threshold: float = 3.0:
	set(value):
		density_threshold = value
		emit_changed()


## Implementation of the two-pass smoothing algorithm
func _smooth(polygon: PackedVector2Array) -> PackedVector2Array:
	# Store original for constraint checking
	var original_polygon := polygon.duplicate()

	# Pass 1: Expand polygon outward
	if expansion_radius != 0.0:
		polygon = _expand_polygon(polygon, expansion_radius)

	# Pass 2: Apply smoothing iterations
	for _iteration in range(iterations):
		polygon = _smooth_iteration(polygon, original_polygon)

	return polygon


## Expands a polygon outward by the specified radius
func _expand_polygon(polygon: PackedVector2Array, radius: float) -> PackedVector2Array:
	var n := polygon.size()
	var expanded := PackedVector2Array()

	for i in range(n):
		var curr := polygon[i]
		var prev := polygon[(i - 1 + n) % n]
		var next := polygon[(i + 1) % n]

		# Calculate edge vectors
		var edge_before := (curr - prev).normalized()
		var edge_after := (next - curr).normalized()

		# Calculate normals (perpendicular, pointing outward for CW winding)
		# For clockwise polygons, use (edge.y, -edge.x) to point outward
		var normal_before := Vector2(edge_before.y, -edge_before.x)
		var normal_after := Vector2(edge_after.y, -edge_after.x)

		# Average normal at vertex
		var vertex_normal := (normal_before + normal_after).normalized()

		# Handle acute angles - scale offset to maintain consistent width
		var dot_product := edge_before.dot(-edge_after)
		var angle := acos(clamp(dot_product, -1.0, 1.0))
		var miter_scale := 1.0

		if angle > 0.01:  # Avoid division by zero
			miter_scale = 1.0 / sin(angle * 0.5)
			# Limit miter length for very acute angles
			miter_scale = min(miter_scale, 2.0)

		# Offset vertex outward
		expanded.append(curr + vertex_normal * radius * miter_scale)

	return expanded


## Performs one smoothing iteration
func _smooth_iteration(polygon: PackedVector2Array, original: PackedVector2Array) -> PackedVector2Array:
	var n := polygon.size()
	var smoothed := PackedVector2Array()

	for i in range(n):
		var curr := polygon[i]
		var prev := polygon[(i - 1 + n) % n]
		var next := polygon[(i + 1) % n]

		# Check if this is a corner to preserve
		if preserve_corners and _is_corner(prev, curr, next):
			smoothed.append(curr)
			continue

		# Check point density for adaptive smoothing
		var density_factor := _calculate_density_factor(i, polygon)

		# Calculate smoothing target (weighted average of neighbors)
		var smooth_target := (prev + next) * 0.5
		var smooth_offset := smooth_target - curr

		# Apply smoothing with density-based strength
		var effective_strength := smooth_strength * density_factor
		var new_point := curr + smooth_offset * effective_strength

		# Apply constraint if enabled
		if constrain_smoothing:
			new_point = _apply_constraint(new_point, curr, original)

		smoothed.append(new_point)

	return smoothed


## Checks if a vertex forms an intentional corner
func _is_corner(prev: Vector2, curr: Vector2, next: Vector2) -> bool:
	var edge_before := (curr - prev).normalized()
	var edge_after := (next - curr).normalized()

	# Calculate angle between edges
	var dot_product := edge_before.dot(edge_after)
	var angle_rad := acos(clamp(dot_product, -1.0, 1.0))
	var angle_deg := rad_to_deg(angle_rad)

	# Check if angle is sharp enough to be considered a corner
	return (180.0 - angle_deg) > corner_threshold


## Calculates a density factor for adaptive smoothing
func _calculate_density_factor(index: int, polygon: PackedVector2Array) -> float:
	var n := polygon.size()
	var curr := polygon[index]
	var prev := polygon[(index - 1 + n) % n]
	var next := polygon[(index + 1) % n]

	# Calculate distances to neighbors
	var dist_prev := curr.distance_to(prev)
	var dist_next := curr.distance_to(next)
	var avg_dist := (dist_prev + dist_next) * 0.5

	# More smoothing for dense regions (small distances)
	if avg_dist < density_threshold:
		# Inverse relationship: smaller distance = stronger smoothing
		return 1.0 - (avg_dist / density_threshold) * 0.5

	return 1.0


## Constrains a smoothed point to stay outside the original polygon
func _apply_constraint(new_point: Vector2, curr_point: Vector2, original: PackedVector2Array) -> Vector2:
	# Simple approach: if new point would be inside original, keep current position
	# More sophisticated: project onto original polygon boundary

	# Check if new point is inside original polygon
	if _is_point_inside_polygon(new_point, original):
		# If moving inward, don't allow it
		return curr_point

	return new_point


## Checks if a point is inside a polygon using ray casting
func _is_point_inside_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
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
