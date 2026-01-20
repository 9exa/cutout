@tool
class_name CutoutSmoothAlgorithm
extends Resource

## Base class for polygon smoothing algorithms.
##
## Smoothing algorithms reduce jagged edges and sharp spikes in polygons
## while attempting to preserve the overall shape. This is particularly useful
## for handling dense point clusters (like spiky hair) after contour extraction.
## Applied after polygon simplification, before mesh generation.

## Smoothing strength. Higher values create smoother results.
## The exact meaning depends on the specific algorithm implementation.
@export_range(0.0, 1.0, 0.01) var smooth_strength: float = 0.5:
	set(value):
		smooth_strength = value
		emit_changed()

## Number of smoothing iterations. More iterations create smoother results
## but may lose detail and increase processing time.
@export_range(1, 10, 1) var iterations: int = 2:
	set(value):
		iterations = value
		emit_changed()

## Smooths a polygon by reducing sharp corners and jagged edges.
##
## Takes an array of 2D points representing a polygon and returns a smoothed
## version. The specific algorithm behavior depends on the concrete implementation.
##
## @param polygon: The input polygon as an array of 2D points
## @return: The smoothed polygon
func smooth(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.is_empty():
		push_warning("CutoutSmoothAlgorithm: Cannot smooth empty polygon")
		return PackedVector2Array()

	if polygon.size() < 3:
		push_warning("CutoutSmoothAlgorithm: Polygon has fewer than 3 points, returning as-is")
		return polygon

	return _smooth(polygon)


## Abstract method to be implemented by concrete smoothing algorithms.
##
## @param _polygon: The input polygon to smooth
## @return: The smoothed polygon
func _smooth(_polygon: PackedVector2Array) -> PackedVector2Array:
	push_error("_smooth() is an abstract method and must be implemented in derived classes")
	return PackedVector2Array()