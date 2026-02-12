extends Node2D

@export var self_intersecting_polygon: Polygon2D

func _ready():
	var points := self_intersecting_polygon.polygon

	var new_points := Geometry2D.merge_polygons(points, points)
	self_intersecting_polygon.polygon = new_points[0]
