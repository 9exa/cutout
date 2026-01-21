@tool
@abstract
class_name CutoutPolysimpAlgorithm
extends Resource

## Base class for polygon simplification algorithms.
##
## Polygon simplification algorithms take an array of 2D points and return
## a simplified version with fewer points while preserving the general shape.
## This is useful for reducing mesh complexity in the image-to-mesh pipeline.



## Simplifies a polygon by reducing the number of points.
##
## Takes an array of 2D points representing a polygon and returns a simplified
## version with fewer points. The specific algorithm behavior depends on the
## concrete implementation.
##
## @param polygon: The input polygon as an array of 2D points
## @return: The simplified polygon with fewer points
func simplify(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.is_empty():
		push_warning("CutoutPolysimpAlgorithm: Cannot simplify empty polygon")
		return PackedVector2Array()

	if polygon.size() < 3:
		push_warning("CutoutPolysimpAlgorithm: Polygon has fewer than 3 points, returning as-is")
		return polygon

	return _simplify(polygon)


## Abstract method to be implemented by concrete simplification algorithms.
##
## @param _polygon: The input polygon to simplify
## @return: The simplified polygon
func _simplify(_polygon: PackedVector2Array) -> PackedVector2Array:
	push_error("_simplify() is an abstract method and must be implemented in derived classes")
	return PackedVector2Array()
