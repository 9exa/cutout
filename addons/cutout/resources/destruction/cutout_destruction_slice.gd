@tool
class_name CutoutDestructionSlice
extends CutoutDestructionAlgorithm

## Simple slice/cut destruction algorithm.
##
## Bisects a polygon along a user-defined line, creating a clean cut.
## This is ideal for slashing effects (sword cuts, laser beams) or any
## gameplay mechanic that requires splitting an object in two.
##
## Unlike other destruction algorithms that create many fragments,
## this always produces exactly 2 pieces (or fewer if the line misses).
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW).


## Start point of the slice line in 2D texture space.
## The line extends infinitely, so only the direction matters.
@export var line_start: Vector2 = Vector2(-100, 0):
	set(value):
		line_start = value
		emit_changed()

## End point of the slice line in 2D texture space.
## Together with line_start, defines the cutting direction.
@export var line_end: Vector2 = Vector2(100, 0):
	set(value):
		line_end = value
		emit_changed()


## Implementation of slice fracture algorithm.
## Delegates to the Rust CutoutDestructionProcessor for performance.
func _fracture(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Validate line
	if line_start.distance_to(line_end) < 0.001:
		push_warning("CutoutDestructionSlice: Line start and end are too close")
		return polygons

	# Delegate to Rust implementation
	var fragments := CutoutDestructionProcessor.fracture_slice(
		polygons,
		line_start,
		line_end
	)

	if fragments.is_empty():
		push_warning("CutoutDestructionSlice: Line did not intersect polygon")
		return polygons

	return fragments


## GDScript reference implementation (kept for fallback/debugging).
## Call this instead of _fracture() if you need the pure-GDScript path.
func _fracture_gdscript(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Validate line
	if line_start.distance_to(line_end) < 0.001:
		push_warning("CutoutDestructionSlice: Line start and end are too close")
		return polygons

	# Use CutoutGeometryUtils for the actual bisection
	var result := CutoutGeometryUtils.bisect_polygon(
		polygons,
		line_start,
		line_end
	)

	# Collect all fragments from both sides
	var fragments: Array[PackedVector2Array] = []

	# Add left side fragments (result[0])
	for poly in result[0]:
		if poly.size() >= 3:  # Valid polygon check
			fragments.append(poly)

	# Add right side fragments (result[1])
	for poly in result[1]:
		if poly.size() >= 3:  # Valid polygon check
			fragments.append(poly)

	# If no valid fragments were created (line missed polygon),
	# return the original
	if fragments.is_empty():
		push_warning("CutoutDestructionSlice: Line did not intersect polygon")
		return polygons

	return fragments