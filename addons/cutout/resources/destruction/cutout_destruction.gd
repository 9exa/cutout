@tool
@abstract
class_name CutoutDestructionAlgorithm
extends Resource

## Base class for polygon destruction algorithms.
##
## Destruction algorithms take a 2D polygon and break it into multiple smaller
## polygon fragments, useful for creating fracture/shatter effects that can then
## be converted into individual CutoutMesh instances.
##
## The destruction happens in 2D space (on the polygon mask) before 3D mesh
## generation, allowing the same destruction algorithm to work regardless of
## extrusion depth or mesh complexity.
##
## WINDING ORDER: Preserves the input polygon's winding order (CW or CCW) for
## all output fragments.


## Random seed for deterministic destruction patterns.
## Use the same seed to get reproducible results, or change it for variation.
@export var seed: int = 0:
	set(value):
		seed = value
		emit_changed()

## Target number of fragments to generate.
## The actual number may vary depending on the algorithm and polygon shape.
@export_range(2, 100, 1) var fragment_count: int = 10:
	set(value):
		fragment_count = value
		emit_changed()


## Fractures a polygon (with optional holes) into multiple smaller fragments.
##
## Takes one or more 2D polygons and returns an array of smaller polygons representing
## the fractured pieces. The input follows Godot's polygon-with-holes convention:
## - First polygon (index 0) is the outer boundary
## - Subsequent polygons (if any) are holes
##
## Each fragment is a valid closed polygon that can be converted to a CutoutMesh.
## Fragments that fall entirely within holes are automatically discarded.
##
## @param polygons: Array of polygons (first = outer boundary, rest = holes)
## @return: Array of polygon fragments, or empty array on failure
func fracture(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if polygons.is_empty():
		push_warning("CutoutDestructionAlgorithm: Cannot fracture empty polygon array")
		return []

	var outer_polygon := polygons[0]

	if outer_polygon.is_empty():
		push_warning("CutoutDestructionAlgorithm: Cannot fracture empty outer polygon")
		return []

	if outer_polygon.size() < 3:
		push_warning("CutoutDestructionAlgorithm: Outer polygon has fewer than 3 points, cannot fracture")
		return []

	# Validate polygon area - too small polygons shouldn't be fractured
	var area := _calculate_polygon_area(outer_polygon)
	if abs(area) < 1.0:  # Minimum area threshold
		push_warning("CutoutDestructionAlgorithm: Polygon area too small for fracturing")
		return []

	return _fracture(polygons)


## Abstract method to be implemented by concrete destruction algorithms.
##
## @param _polygons: Array of polygons (first = outer boundary, rest = holes)
## @return: Array of polygon fragments
func _fracture(_polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	push_error("_fracture() is an abstract method and must be implemented in derived classes")
	return []


## Calculates the signed area of a polygon using the shoelace formula.
## Positive area indicates CCW winding, negative indicates CW winding.
func _calculate_polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	var n := polygon.size()

	for i in range(n):
		var j := (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y

	return area * 0.5
