extends Node2D

var CutoutGeometryUtils = load("res://addons/cutout/utils/cutout_geometry_utils.gd")

@export var polygon: PackedVector2Array
@export var bisection: SegmentShape2D

func _ready():
	var polygons: Array[PackedVector2Array]
	polygons.append(polygon)

	var result := CutoutGeometryUtils.bisect_polygon(
		polygons,
		bisection.a,
		bisection.b
	)

	print("Left Polygons:")
	for left_poly in result[0]:
		print(left_poly)

	print("Right Polygons:")
	for right_poly in result[1]:
		print(right_poly)
