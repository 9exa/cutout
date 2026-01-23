@tool
extends Node2D

var texture: Texture2D
var polygon: PackedVector2Array
var polygon_color: Color = Color(0, 1, 0, 0.5)
var polygon_line_color: Color = Color(0, 1, 0, 1)
var polygon_line_width: float = 2.0
var show_points: bool = true
var point_radius: float = 3.0
var point_color: Color = Color(1, 0, 0, 1)

func _ready():
	set_process(false)

func set_texture(tex: Texture2D):
	texture = tex
	queue_redraw()

func set_polygon(poly: PackedVector2Array):
	polygon = poly
	queue_redraw()

func set_colors(fill: Color, line: Color, points: Color):
	polygon_color = fill
	polygon_line_color = line
	point_color = points
	queue_redraw()

func _draw():
	# Draw texture
	if texture:
		draw_texture(texture, Vector2.ZERO)

	# Draw polygon
	if polygon and polygon.size() >= 3:
		# Draw filled polygon
		draw_colored_polygon(polygon, polygon_color)

		# Draw polygon outline
		for i in polygon.size():
			var p1 = polygon[i]
			var p2 = polygon[(i + 1) % polygon.size()]
			draw_line(p1, p2, polygon_line_color, polygon_line_width)

		# Draw points
		if show_points:
			for point in polygon:
				draw_circle(point, point_radius, point_color)

func clear():
	polygon = PackedVector2Array()
	queue_redraw()

func get_bounds() -> Rect2:
	if texture:
		return Rect2(Vector2.ZERO, texture.get_size())
	elif polygon and polygon.size() > 0:
		var min_point = polygon[0]
		var max_point = polygon[0]
		for point in polygon:
			min_point.x = min(min_point.x, point.x)
			min_point.y = min(min_point.y, point.y)
			max_point.x = max(max_point.x, point.x)
			max_point.y = max(max_point.y, point.y)
		return Rect2(min_point, max_point - min_point)
	else:
		return Rect2()