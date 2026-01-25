class_name CutoutGeometryUtils
extends RefCounted

## Utility class for polygon triangulation and geometric testing
## All methods are static for easy reuse across different scripts

# Triangulate polygon with multiple fallback methods for robustness
static func triangulate_with_fallbacks(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		print("[CutoutGeometryUtils] Triangulation skipped: polygon has less than 3 points")
		return PackedInt32Array()

	# Initial state logging
	var area := compute_polygon_area(points)
	var is_clockwise := area < 0
	print("[CutoutGeometryUtils] Starting triangulation for polygon with ", points.size(), " points")
	print("[CutoutGeometryUtils] Area: ", area, ", Winding: ", "CW" if is_clockwise else "CCW")

	# Method 1: Godot's triangulate_polygon expects CCW winding
	# Incoming points are already CCW after Y-flip in CutoutMesh, so use them directly
	print("[CutoutGeometryUtils] Method 1: Attempting Godot triangulator (trusting incoming winding)")

	var triangles := Geometry2D.triangulate_polygon(points)
	if not triangles.is_empty():
		print("[CutoutGeometryUtils] Method 1: SUCCESS - Generated ", triangles.size() / 3, " triangles")
		return triangles
	print("[CutoutGeometryUtils] Method 1: FAILED - returned empty")

	# Method 2: Try the opposite winding if first attempt failed
	print("[CutoutGeometryUtils] Method 2: Attempting opposite winding")
	var opposite_points := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		opposite_points.append(points[i])
	triangles = Geometry2D.triangulate_polygon(opposite_points)
	if not triangles.is_empty():
		print("[CutoutGeometryUtils] Method 2: SUCCESS - Generated ", triangles.size() / 3, " triangles")
		return triangles
	print("[CutoutGeometryUtils] Method 2: FAILED - returned empty")

	# Method 3: Try removing duplicate/degenerate vertices
	print("[CutoutGeometryUtils] Method 3: Cleaning degenerate vertices")
	var cleaned := clean_polygon(points)
	var removed_count := points.size() - cleaned.size()
	print("[CutoutGeometryUtils] Method 3: Removed ", removed_count, " vertices (", cleaned.size(), " remaining)")
	if cleaned.size() >= 3:
		triangles = Geometry2D.triangulate_polygon(cleaned)
		if not triangles.is_empty():
			print("[CutoutGeometryUtils] Method 3: SUCCESS - Generated ", triangles.size() / 3, " triangles")
			return triangles
	print("[CutoutGeometryUtils] Method 3: FAILED - returned empty")

	# Method 4: Fallback to ear clipping algorithm
	print("[CutoutGeometryUtils] Method 4: Attempting custom ear clipping")
	triangles = ear_clipping_triangulation(points)
	if not triangles.is_empty():
		print("[CutoutGeometryUtils] Method 4: SUCCESS - Generated ", triangles.size() / 3, " triangles")
		return triangles
	print("[CutoutGeometryUtils] Method 4: FAILED - ear clipping failed")

	# Method 5: Last resort - use convex hull
	push_warning("[CutoutGeometryUtils] ⚠️ WARNING: Method 5 - Using CONVEX HULL fallback")
	push_warning("[CutoutGeometryUtils] ⚠️ This will create triangles OUTSIDE the polygon boundary!")
	print("[CutoutGeometryUtils] Method 5: Generating convex hull")
	var hull := Geometry2D.convex_hull(points)
	print("[CutoutGeometryUtils] Method 5: Hull has ", hull.size(), " points (original had ", points.size(), " points)")
	triangles = Geometry2D.triangulate_polygon(hull)
	print("[CutoutGeometryUtils] Method 5: Generated ", triangles.size() / 3, " triangles from convex hull")
	return triangles

# Test if polygon has self-intersecting edges
static func has_self_intersections(polygon: PackedVector2Array) -> bool:
	"""Check if polygon has self-intersecting edges (non-simple polygon)."""
	if polygon.size() < 4:
		return false

	var n = polygon.size()

	# Check each edge against non-adjacent edges
	for i in range(n):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % n]

		# Skip adjacent edges
		for j in range(i + 2, n):
			if j == (i + n - 1) % n:  # Skip adjacent edges
				continue

			var p3 = polygon[j]
			var p4 = polygon[(j + 1) % n]

			if _segments_intersect(p1, p2, p3, p4):
				print("[CutoutGeometryUtils] Self-intersection detected between edges ", i, " and ", j)
				return true

	return false

# Test if two line segments intersect (excluding endpoints)
static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	"""Check if two line segments intersect (excluding endpoints)."""
	var d1 = _ccw(p1, p3, p4)
	var d2 = _ccw(p2, p3, p4)
	var d3 = _ccw(p1, p2, p3)
	var d4 = _ccw(p1, p2, p4)

	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
	       ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))

# Counter-clockwise test using cross product
static func _ccw(a: Vector2, b: Vector2, c: Vector2) -> float:
	"""Counter-clockwise test (cross product). Positive = CCW turn, negative = CW turn."""
	return (c.y - a.y) * (b.x - a.x) - (b.y - a.y) * (c.x - a.x)

# Remove duplicate and degenerate vertices from polygon
static func clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var cleaned := PackedVector2Array()
	var epsilon := 1.0  # Tolerance for duplicate detection (increased for larger cap)

	for i in range(points.size()):
		var p := points[i]
		var should_add := true

		# Check if this point is too close to the last added point
		if cleaned.size() > 0:
			var last := cleaned[cleaned.size() - 1]
			if (p - last).length() < epsilon:
				should_add = false

		if should_add:
			cleaned.append(p)

	# Check if first and last points are too close (closed polygon)
	if cleaned.size() > 2:
		if (cleaned[0] - cleaned[cleaned.size() - 1]).length() < epsilon:
			cleaned.remove_at(cleaned.size() - 1)

	return cleaned

# Proper ear clipping triangulation algorithm for concave polygons
static func ear_clipping_triangulation(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		return PackedInt32Array()

	if points.size() == 3:
		# Already a triangle
		return PackedInt32Array([0, 1, 2])

	var indices := PackedInt32Array()
	var vertices := []

	# Create a doubly-linked list of vertices
	for i in range(points.size()):
		vertices.append({
			"index": i,
			"pos": points[i],
			"is_ear": false,
			"is_convex": false
		})

	# Determine if polygon is clockwise or counter-clockwise
	var area := compute_polygon_area(points)
	var ccw := area > 0

	# Update convex/reflex status for all vertices
	for i in range(vertices.size()):
		var prev := (i - 1 + vertices.size()) % vertices.size()
		var next := (i + 1) % vertices.size()
		vertices[i].is_convex = is_convex_vertex(points[prev], points[i], points[next], ccw)

	# Find initial ears
	for i in range(vertices.size()):
		if vertices[i].is_convex:
			vertices[i].is_ear = _is_ear(i, vertices, points)

	# Process ears
	var remaining := vertices.size()
	var current := 0
	var safety := 0

	while remaining > 3 and safety < 1000:
		safety += 1

		# Find an ear
		var ear_found := false
		for attempt in range(remaining):
			var idx := (current + attempt) % vertices.size()
			if vertices[idx] != null and vertices[idx].is_ear:
				# Found an ear, clip it
				var prev_idx := _get_prev_vertex(idx, vertices)
				var next_idx := _get_next_vertex(idx, vertices)

				# Add triangle
				indices.append(vertices[prev_idx].index)
				indices.append(vertices[idx].index)
				indices.append(vertices[next_idx].index)

				# Remove the ear vertex
				vertices[idx] = null
				remaining -= 1

				# Update neighbors
				if vertices[prev_idx] != null:
					var pp := _get_prev_vertex(prev_idx, vertices)
					vertices[prev_idx].is_convex = is_convex_vertex(
						points[vertices[pp].index],
						points[vertices[prev_idx].index],
						points[vertices[next_idx].index],
						ccw
					)
					if vertices[prev_idx].is_convex:
						vertices[prev_idx].is_ear = _is_ear(prev_idx, vertices, points)

				if vertices[next_idx] != null:
					var nn := _get_next_vertex(next_idx, vertices)
					vertices[next_idx].is_convex = is_convex_vertex(
						points[vertices[prev_idx].index],
						points[vertices[next_idx].index],
						points[vertices[nn].index],
						ccw
					)
					if vertices[next_idx].is_convex:
						vertices[next_idx].is_ear = _is_ear(next_idx, vertices, points)

				ear_found = true
				current = next_idx
				break

		if not ear_found:
			break

	# Add final triangle
	if remaining == 3:
		var final_vertices := []
		for v in vertices:
			if v != null:
				final_vertices.append(v.index)
		if final_vertices.size() == 3:
			indices.append(final_vertices[0])
			indices.append(final_vertices[1])
			indices.append(final_vertices[2])

	return indices

# Helper: Get previous non-null vertex index
static func _get_prev_vertex(idx: int, vertices: Array) -> int:
	var n := vertices.size()
	for i in range(1, n):
		var prev := (idx - i + n) % n
		if vertices[prev] != null:
			return prev
	return -1

# Helper: Get next non-null vertex index
static func _get_next_vertex(idx: int, vertices: Array) -> int:
	var n := vertices.size()
	for i in range(1, n):
		var next := (idx + i) % n
		if vertices[next] != null:
			return next
	return -1

# Compute signed area of polygon (positive if CCW, negative if CW)
static func compute_polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var n := points.size()
	for i in range(n):
		var j := (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	return area * 0.5

# Check if three consecutive vertices form a convex angle
static func is_convex_vertex(prev: Vector2, curr: Vector2, next: Vector2, ccw: bool) -> bool:
	var cross := (curr - prev).cross(next - curr)
	return (cross > 0) == ccw

# Check if a vertex forms an ear
static func _is_ear(vertex_idx: int, vertices: Array, points: PackedVector2Array) -> bool:
	if not vertices[vertex_idx].is_convex:
		return false

	var prev_idx := _get_prev_vertex(vertex_idx, vertices)
	var next_idx := _get_next_vertex(vertex_idx, vertices)

	if prev_idx == -1 or next_idx == -1:
		return false

	var a := points[vertices[prev_idx].index]
	var b := points[vertices[vertex_idx].index]
	var c := points[vertices[next_idx].index]

	# Check if any other vertex is inside this triangle
	for i in range(vertices.size()):
		if vertices[i] == null or i == prev_idx or i == vertex_idx or i == next_idx:
			continue

		if point_in_triangle(points[vertices[i].index], a, b, c):
			return false

	return true

# Check if a point is inside a triangle using barycentric coordinates
static func point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a

	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)

	var inv_denom := 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u := (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v := (dot00 * dot12 - dot01 * dot02) * inv_denom

	return (u >= 0) and (v >= 0) and (u + v <= 1)

# Calculate distance from point to line segment
static func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec := line_end - line_start
	var point_vec := point - line_start
	var line_len := line_vec.length()

	if line_len == 0:
		return point_vec.length()

	var projection := point_vec.dot(line_vec) / (line_len * line_len)
	projection = clamp(projection, 0.0, 1.0)

	var closest := line_start + line_vec * projection
	return (point - closest).length()
