class_name ContourUtils
extends RefCounted

## Utility class for contour extraction, simplification, and triangulation
## All methods are static for easy reuse across different scripts

# Moore neighborhood contour following algorithm
static func extract_contour(image: Image, alpha_threshold: float = 0.5) -> PackedVector2Array:
	var width := image.get_width()
	var height := image.get_height()

	# Decompress if needed
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()

	# Find the topmost-leftmost opaque pixel as starting point
	var start_pixel := Vector2i(-1, -1)
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a >= alpha_threshold:
				# Check if this is an edge pixel
				var is_edge := false
				if x == 0 or image.get_pixel(x-1, y).a < alpha_threshold:
					is_edge = true
				elif y == 0 or image.get_pixel(x, y-1).a < alpha_threshold:
					is_edge = true

				if is_edge:
					start_pixel = Vector2i(x, y)
					break
		if start_pixel.x != -1:
			break

	if start_pixel.x == -1:
		return PackedVector2Array()

	# Moore neighborhood directions (clockwise from west)
	var directions := [
		Vector2i(-1, 0),  # 0: W
		Vector2i(-1, -1), # 1: NW
		Vector2i(0, -1),  # 2: N
		Vector2i(1, -1),  # 3: NE
		Vector2i(1, 0),   # 4: E
		Vector2i(1, 1),   # 5: SE
		Vector2i(0, 1),   # 6: S
		Vector2i(-1, 1)   # 7: SW
	]

	var contour := PackedVector2Array()
	var current := start_pixel
	var entered_from := 0  # Initially entered from west
	var contour_started := false

	# Helper function to check if pixel is opaque and in bounds
	var is_solid = func(p: Vector2i) -> bool:
		if p.x < 0 or p.x >= width or p.y < 0 or p.y >= height:
			return false
		return image.get_pixel(p.x, p.y).a >= alpha_threshold

	# Main contour tracing loop
	var max_points := width * height * 2  # Safety limit
	while contour.size() < max_points:
		# Add current pixel to contour
		if not contour_started or current != start_pixel:
			contour.append(Vector2(current))
			contour_started = true

		# Start checking from the direction we entered + 2 (90 degrees right)
		var check_start := (entered_from + 2) % 8
		var next_pixel := Vector2i(-1, -1)
		var next_dir := -1

		# Check all 8 directions starting from check_start
		for i in range(8):
			var dir: int = (check_start + i) % 8
			var neighbor: Vector2i = current + directions[dir]

			if is_solid.call(neighbor):
				next_pixel = neighbor
				next_dir = dir
				break

		# If we found a next pixel
		if next_pixel.x != -1:
			# If we've returned to start and have traced enough
			if next_pixel == start_pixel and contour.size() > 2:
				break

			current = next_pixel
			# The direction we entered the new pixel from (opposite of direction we moved)
			entered_from = (next_dir + 4) % 8
		else:
			# Isolated pixel
			break

	return contour

# Douglas-Peucker polygon simplification
static func simplify_polygon(points: PackedVector2Array, threshold: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	# Find the point with maximum distance from the line between first and last
	var max_dist := 0.0
	var max_index := 0

	for i in range(1, points.size() - 1):
		var dist := point_to_line_distance(points[i], points[0], points[points.size() - 1])
		if dist > max_dist:
			max_dist = dist
			max_index = i

	# If max distance is greater than threshold, recursively simplify
	if max_dist > threshold:
		# Recursively simplify both segments
		var left_segment := points.slice(0, max_index + 1)
		var right_segment := points.slice(max_index)

		var left_simplified := simplify_polygon(left_segment, threshold)
		var right_simplified := simplify_polygon(right_segment, threshold)

		# Combine results (remove duplicate middle point)
		var result := PackedVector2Array()
		for i in range(left_simplified.size() - 1):
			result.append(left_simplified[i])
		for point in right_simplified:
			result.append(point)

		return result
	else:
		# Return just the endpoints
		return PackedVector2Array([points[0], points[points.size() - 1]])

# Triangulate polygon with multiple fallback methods for robustness
static func triangulate_with_fallbacks(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		return PackedInt32Array()

	# Method 1: Try standard triangulation
	var triangles := Geometry2D.triangulate_polygon(points)
	if not triangles.is_empty():
		return triangles

	# Method 2: Try after ensuring proper winding order (CCW)
	var reversed := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		reversed.append(points[i])
	triangles = Geometry2D.triangulate_polygon(reversed)
	if not triangles.is_empty():
		return triangles

	# Method 3: Try removing duplicate/degenerate vertices
	var cleaned := clean_polygon(points)
	if cleaned.size() >= 3:
		triangles = Geometry2D.triangulate_polygon(cleaned)
		if not triangles.is_empty():
			return triangles

	# Method 4: Fallback to ear clipping algorithm
	triangles = ear_clipping_triangulation(points)
	if not triangles.is_empty():
		return triangles

	# Method 5: Last resort - use convex hull
	var hull := Geometry2D.convex_hull(points)
	triangles = Geometry2D.triangulate_polygon(hull)
	return triangles

# Remove duplicate and degenerate vertices from polygon
static func clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var cleaned := PackedVector2Array()
	var epsilon := 0.001  # Tolerance for duplicate detection

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
