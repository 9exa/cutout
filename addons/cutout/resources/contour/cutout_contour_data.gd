@tool
class_name CutoutContourData
extends Resource

## The calculated points of the contour
@export var points: Array[PackedVector2Array] = []

func clear() -> void:
	points.clear()
	emit_changed()
