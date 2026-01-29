class_name CutoutGeometryUtils
extends RefCounted

## Utility class for polygon triangulation and geometric testing
## All methods are static for easy reuse across different scripts


# =============================================================================
# PUBLIC API - Triangulation
# =============================================================================

## Triangulate polygon with multiple fallback methods for robustness.
static func triangulate_with_fallbacks(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		
		return PackedInt32Array()

	# Initial state logging
	var area := compute_polygon_area(points)
	var is_clockwise := area < 0

	# Method 1: Godot's triangulate_polygon expects CCW winding
	# Incoming points are already CCW after Y-flip in CutoutMesh, so use them directly

	var triangles := Geometry2D.triangulate_polygon(points)
	if not triangles.is_empty():
		
		return triangles

	# Method 2: Try the opposite winding if first attempt failed
	
	var opposite_points := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		opposite_points.append(points[i])
	triangles = Geometry2D.triangulate_polygon(opposite_points)
	if not triangles.is_empty():
		
		return triangles
	

	# Method 3: Try removing duplicate/degenerate vertices
	
	var cleaned := clean_polygon(points)
	var removed_count := points.size() - cleaned.size()
	
	if cleaned.size() >= 3:
		triangles = Geometry2D.triangulate_polygon(cleaned)
		if not triangles.is_empty():
			
			return triangles
	

	# Method 4: Fallback to ear clipping algorithm
	
	triangles = ear_clipping_triangulation(points)
	if not triangles.is_empty():
		
		return triangles
	

	# Method 5: Last resort - use convex hull
	push_warning("[CutoutGeometryUtils] ⚠️ WARNING: Method 5 - Using CONVEX HULL fallback")
	push_warning("[CutoutGeometryUtils] ⚠️ This will create triangles OUTSIDE the polygon boundary!")
	
	var hull := Geometry2D.convex_hull(points)
	
	triangles = Geometry2D.triangulate_polygon(hull)
	
	return triangles


## Proper ear clipping triangulation algorithm for concave polygons.
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
		vertices[i].is_convex = _is_convex_vertex(points[prev], points[i], points[next], ccw)

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
					vertices[prev_idx].is_convex = _is_convex_vertex(
						points[vertices[pp].index],
						points[vertices[prev_idx].index],
						points[vertices[next_idx].index],
						ccw
					)
					if vertices[prev_idx].is_convex:
						vertices[prev_idx].is_ear = _is_ear(prev_idx, vertices, points)

				if vertices[next_idx] != null:
					var nn := _get_next_vertex(next_idx, vertices)
					vertices[next_idx].is_convex = _is_convex_vertex(
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


# =============================================================================
# PUBLIC API - Polygon Testing & Utilities
# =============================================================================

## Check if polygon has self-intersecting edges (non-simple polygon).
static func has_self_intersections(polygon: PackedVector2Array) -> bool:
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
				return true

	return false


## Remove duplicate and degenerate vertices from polygon.
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


## Compute signed area of polygon (positive if CCW, negative if CW).
static func compute_polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var n := points.size()
	for i in range(n):
		var j := (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	return area * 0.5


## Calculate distance from point to line segment.
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


## Test if a polygon is convex using cross product sign consistency.
##
## A polygon is convex if all interior angles are less than 180 degrees,
## which means all cross products of consecutive edge vectors have the same sign.
##
## Returns true if convex, false if concave or degenerate.
## Time complexity: O(n) with early exit on first sign change.
static func is_polygon_convex(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false

	var n := polygon.size()
	var sign := 0  # 1 = all CCW turns, -1 = all CW turns, 0 = not yet determined

	for i in range(n):
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % n]
		var p3 := polygon[(i + 2) % n]

		# Calculate cross product of consecutive edges
		var edge1 := p2 - p1
		var edge2 := p3 - p2
		var cross := edge1.cross(edge2)

		# Skip nearly collinear points (tolerance for floating point errors)
		if abs(cross) > 0.0001:
			var current_sign := 1 if cross > 0 else -1

			if sign == 0:
				# First non-collinear vertex sets the expected sign
				sign = current_sign
			elif sign != current_sign:
				# Found inconsistent turn direction = concave
				return false

	return true


# =============================================================================
# PUBLIC API - Polygon Bisection
# =============================================================================

## Bisects a polygon (with optional holes) across an infinite line.
##
## Automatically chooses between fast O(n) algorithm for convex polygons
## or robust Clipper-based algorithm for concave polygons and holes.
##
## Args:
## 	polygons: Array where first element is outer boundary, rest are holes (if any)
## 	line_start: Start point defining the bisection line
## 	line_end: End point defining the bisection line
##
## Returns:
## 	Dictionary with format:
## 	{
## 		"left": [polygon1, polygon2, ...],   # Fragments on left side of line
## 		"right": [polygon1, polygon2, ...]   # Fragments on right side of line
## 	}
## 	The "left" side is determined by the perpendicular normal pointing left
## 	from the line direction (line_start -> line_end).
##
## Note: Result arrays may contain multiple polygons if bisection creates
## disconnected fragments (common with concave shapes).
static func bisect_polygon(
	polygons: Array[PackedVector2Array],
	line_start: Vector2,
	line_end: Vector2
) -> Array:
	if polygons.is_empty():
		return [[], []]

	var outer_polygon := polygons[0]

	if outer_polygon.size() < 3:
		return [[], []]

	# Case 1: Multiple polygons means we have holes -> use robust algorithm
	if polygons.size() > 1:
		var result := bisect_polygon_robust(polygons, line_start, line_end)
		return [result["left"], result["right"]]

	# Case 2: Check if convex (cheap O(n) test with early exit)
	if is_polygon_convex(outer_polygon):
		# Fast path: Simple edge intersection algorithm
		print("[CutoutGeometryUtils] Using fast bisect for convex polygon")
		var result := bisect_polygon_simple(outer_polygon, line_start, line_end)
		return [
			[result[0]] if result[0].size() >= 3 else [],
			[result[1]] if result[1].size() >= 3 else []
		]

	# Case 3: Concave polygon -> use robust algorithm
	print("[CutoutGeometryUtils] Using robust bisect for concave polygon")
	var result := bisect_polygon_robust(polygons, line_start, line_end)
	return [result["left"], result["right"]]


## Fast O(n) bisection algorithm for convex polygons only.
##
## Uses simple edge-intersection approach. Does NOT handle concave polygons
## or holes correctly - use bisect_polygon_robust() for those cases.
##
## Returns: [left_polygon, right_polygon] (may be empty if entirely on one side)
static func bisect_polygon_simple(
	polygon: PackedVector2Array,
	line_start: Vector2,
	line_end: Vector2
) -> Array[PackedVector2Array]:
	if polygon.size() < 3:
		return [PackedVector2Array(), PackedVector2Array()]

	const EPSILON := 0.0001

	# Calculate line normal (points to "left" side)
	var line_vec := line_end - line_start
	var line_normal := Vector2(-line_vec.y, line_vec.x).normalized()

	# Classify each vertex by which side of the line it's on
	var side_classification := PackedInt32Array()

	for vertex in polygon:
		var dist := (vertex - line_start).dot(line_normal)

		if dist > EPSILON:
			side_classification.append(1)   # Left/positive side
		elif dist < -EPSILON:
			side_classification.append(-1)  # Right/negative side
		else:
			side_classification.append(0)   # On the line

	# Check if polygon actually intersects the line
	var has_left := false
	var has_right := false
	for side in side_classification:
		if side > 0: has_left = true
		if side < 0: has_right = true

	# Edge case: Polygon entirely on one side
	if not has_left:
		return [PackedVector2Array(), polygon]  # All on right
	if not has_right:
		return [polygon, PackedVector2Array()]  # All on left

	# Build the two split polygons
	var left_poly := PackedVector2Array()
	var right_poly := PackedVector2Array()

	var n := polygon.size()

	for i in range(n):
		var current := polygon[i]
		var next := polygon[(i + 1) % n]

		var current_side := side_classification[i]
		var next_side := side_classification[(i + 1) % n]

		# Add current vertex to appropriate polygon(s)
		if current_side >= 0:  # On left or on line
			left_poly.append(current)
		if current_side <= 0:  # On right or on line
			right_poly.append(current)

		# Check if edge crosses the line (different non-zero sides)
		if current_side * next_side < 0:  # Different sides (excluding on-line)
			# Calculate intersection point
			var intersection := _line_intersection(current, next, line_start, line_end)

			if intersection != Vector2.INF:
				# Add intersection to both polygons
				left_poly.append(intersection)
				right_poly.append(intersection)

	return [left_poly, right_poly]


## Robust polygon bisection using Geometry2D boolean operations.
##
## Handles all cases: convex, concave, and polygons with holes.
## Uses Godot's Clipper library for robust geometric operations.
##
## Returns:
## 	Dictionary with "left" and "right" arrays of polygon fragments.
## 	Each side may contain multiple disconnected polygons.
static func bisect_polygon_robust(
	polygons: Array[PackedVector2Array],
	line_start: Vector2,
	line_end: Vector2
) -> Dictionary:
	if polygons.is_empty():
		return {"left": [], "right": []}

	var outer_polygon := polygons[0]

	if outer_polygon.size() < 3:
		return {"left": [], "right": []}

	# Create two large half-plane rectangles for clipping
	var far_distance := 100000.0
	var line_vec := (line_end - line_start).normalized()
	var perpendicular := Vector2(-line_vec.y, line_vec.x)

	# Create an extended line segment (far in both directions)
	var line_far_start := line_start - line_vec * far_distance
	var line_far_end := line_start + line_vec * far_distance

	# Left half-plane (huge rectangle on the left side of the line)
	# Winding order: counter-clockwise for Clipper
	var left_half_plane := PackedVector2Array([
		line_far_start,
		line_far_end,
		line_far_end + perpendicular * far_distance,
		line_far_start + perpendicular * far_distance
	])

	# Right half-plane (opposite side)
	# Winding order: counter-clockwise for Clipper
	var right_half_plane := PackedVector2Array([
		line_far_start,
		line_far_start - perpendicular * far_distance,
		line_far_end - perpendicular * far_distance,
		line_far_end
	])

	# Intersect outer polygon with each half-plane
	var left_results := Geometry2D.intersect_polygons(outer_polygon, left_half_plane)
	var right_results := Geometry2D.intersect_polygons(outer_polygon, right_half_plane)

	# Spatial culling optimization: Precompute hole bounding boxes
	var hole_bounds: Array[Rect2] = []
	for hole_idx in range(1, polygons.size()):
		hole_bounds.append(_calculate_bounds(polygons[hole_idx]))

	# Process left side - subtract holes from each fragment
	var left_fragments: Array[PackedVector2Array] = []
	for fragment in left_results:
		var remaining := [fragment]
		var fragment_bounds := _calculate_bounds(fragment)

		# Subtract each hole (with spatial culling)
		for hole_idx in range(1, polygons.size()):
			# Spatial culling: Skip holes that don't overlap fragment bounds
			if not fragment_bounds.intersects(hole_bounds[hole_idx - 1]):
				continue

			var hole := polygons[hole_idx]
			var next_remaining: Array[PackedVector2Array] = []

			for piece in remaining:
				var after_subtract := Geometry2D.clip_polygons(piece, hole)
				next_remaining.append_array(after_subtract)

			remaining = next_remaining

		# Add all surviving fragments
		for final_piece in remaining:
			if final_piece.size() >= 3:
				left_fragments.append(final_piece)

	# Process right side - subtract holes from each fragment
	var right_fragments: Array[PackedVector2Array] = []
	for fragment in right_results:
		var remaining := [fragment]
		var fragment_bounds := _calculate_bounds(fragment)

		# Subtract each hole (with spatial culling)
		for hole_idx in range(1, polygons.size()):
			# Spatial culling: Skip holes that don't overlap fragment bounds
			if not fragment_bounds.intersects(hole_bounds[hole_idx - 1]):
				continue

			var hole := polygons[hole_idx]
			var next_remaining: Array[PackedVector2Array] = []

			for piece in remaining:
				var after_subtract := Geometry2D.clip_polygons(piece, hole)
				next_remaining.append_array(after_subtract)

			remaining = next_remaining

		# Add all surviving fragments
		for final_piece in remaining:
			if final_piece.size() >= 3:
				right_fragments.append(final_piece)

	return {
		"left": left_fragments,
		"right": right_fragments
	}


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

# Check if two line segments intersect (excluding endpoints).
static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1 = _ccw(p1, p3, p4)
	var d2 = _ccw(p2, p3, p4)
	var d3 = _ccw(p1, p2, p3)
	var d4 = _ccw(p1, p2, p4)

	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
	       ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))


# Counter-clockwise test (cross product). Positive = CCW turn, negative = CW turn.
static func _ccw(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (c.y - a.y) * (b.x - a.x) - (b.y - a.y) * (c.x - a.x)


# Get previous non-null vertex index.
static func _get_prev_vertex(idx: int, vertices: Array) -> int:
	var n := vertices.size()
	for i in range(1, n):
		var prev := (idx - i + n) % n
		if vertices[prev] != null:
			return prev
	return -1

# Get next non-null vertex index.
static func _get_next_vertex(idx: int, vertices: Array) -> int:
	var n := vertices.size()
	for i in range(1, n):
		var next := (idx + i) % n
		if vertices[next] != null:
			return next
	return -1


# Check if three consecutive vertices form a convex angle.
static func _is_convex_vertex(prev: Vector2, curr: Vector2, next: Vector2, ccw: bool) -> bool:
	var cross := (curr - prev).cross(next - curr)
	return (cross > 0) == ccw


# Check if a vertex forms an ear.
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

		if _point_in_triangle(points[vertices[i].index], a, b, c):
			return false

	return true

# Check if a point is inside a triangle using barycentric coordinates.
static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
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


# Calculate intersection between line segment and infinite line.
#
# Uses matrix inversion to solve the system:
#   seg_start + t * seg_vec = line_start + s * line_vec
#
# Returns Vector2.INF if lines are parallel (determinant near zero).
static func _line_intersection(
	seg_start: Vector2,
	seg_end: Vector2,
	line_start: Vector2,
	line_end: Vector2
) -> Vector2:
	var seg_vec := seg_end - seg_start
	var line_vec := line_end - line_start

	# Calculate determinant of the coefficient matrix
	# det = | seg_vec.x  -line_vec.x |
	#       | seg_vec.y  -line_vec.y |
	var determinant := seg_vec.y * line_vec.x - seg_vec.x * line_vec.y

	# Check if lines are parallel (determinant near zero)
	if abs(determinant) < 0.0001:
		return Vector2.INF

	# Solve for t using Cramer's rule
	# diff = line_start - seg_start (RHS of equation)
	var diff := line_start - seg_start
	var t := (diff.y * line_vec.x - diff.x * line_vec.y) / determinant

	# Calculate intersection point along the segment
	var intersection := seg_start + seg_vec * t

	return intersection


# Calculate axis-aligned bounding box for a polygon.
static func _calculate_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_y := polygon[0].y
	var max_y := polygon[0].y

	for p in polygon:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
