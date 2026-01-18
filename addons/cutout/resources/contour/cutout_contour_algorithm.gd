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

## Produce the boundary points from a given image.
func calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	if image == null:
		return []

	return _calculate_boundary(image)
	


## Virtual. Concrete implementation of calculate_boundary
@abstract func _calculate_boundary(_image: Image) -> Array[PackedVector2Array]
