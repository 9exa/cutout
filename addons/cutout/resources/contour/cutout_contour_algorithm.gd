@tool
@abstract
class_name CutoutContourAlgorithm
extends Resource
## Algorithms for producing CutoutContourData fromtextures.


## The transparency level (0.0 to 1.0) to consider a pixel "solid"
@export_range(0.0, 1.0) var alpha_threshold: float = 0.5:
	set(value):
		alpha_threshold = value
		emit_changed()

## Maximum resolution for contour generation (0 = no downscaling)
## High-res images will be downscaled to fit within this dimension for processing,
## then contour points are scaled back to original coordinates for accuracy.
## Improves performance significantly for large images (e.g., 2048x2048 → 512x512).
@export_range(0, 4096, 1, "or_greater") var max_resolution: int = 0:
	set(value):
		max_resolution = value
		emit_changed()

## Produce the boundary points from a given image.
func calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	if image == null:
		return []

	return _calculate_boundary(image)
	


## Virtual. Concrete implementation of calculate_boundary
@abstract func _calculate_boundary(_image: Image) -> Array[PackedVector2Array]
