@tool
extends CutoutContourAlgorithm
class_name CutoutContourMarchingSquares

## Optimized marching squares algorithm for extracting contours from images.
## Uses single-pass edge detection and efficient contour tracing.
##
## WINDING ORDER: Produces clockwise (CW) polygons consistent with Godot's
## convention where CW = solid and CCW = hole.

const DISPLAY_NAME := "Marching Squares"

# Edge Indices for marching squares
const EDGE_TOP    = 0
const EDGE_RIGHT  = 1
const EDGE_BOTTOM = 2
const EDGE_LEFT   = 3

# Marching squares lookup table
# Each configuration maps to edge connections
const MARCHING_SQUARES_TABLE = [
	[],                     # 0: empty
	[[3, 2]],              # 1: bottom-left corner
	[[2, 1]],              # 2: bottom-right corner
	[[3, 1]],              # 3: bottom edge
	[[1, 0]],              # 4: top-right corner
	[[3, 2], [1, 0]],      # 5: diagonal (saddle point)
	[[2, 0]],              # 6: right edge
	[[3, 0]],              # 7: top-right filled
	[[0, 3]],              # 8: top-left corner
	[[0, 2]],              # 9: left edge
	[[0, 3], [2, 1]],      # 10: diagonal (saddle point)
	[[0, 1]],              # 11: top-left filled
	[[1, 3]],              # 12: top edge
	[[1, 2]],              # 13: bottom-left filled
	[[2, 3]],              # 14: top-left filled
	[]                      # 15: full
]

# Direction vectors for neighbor checking (clockwise from top)
const DIRECTIONS = [
	Vector2i(0, -1),  # Top
	Vector2i(1, 0),   # Right
	Vector2i(0, 1),   # Bottom
	Vector2i(-1, 0)   # Left
]

func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	# Prepare image for BitMap (must be LA8 and uncompressed)
	var converted_image := image.duplicate()
	if converted_image.is_compressed():
		converted_image.decompress()
	converted_image.convert(Image.FORMAT_LA8)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(converted_image, alpha_threshold)

	return _marching_squares_optimized(bitmap)


## Optimized marching squares with single-pass edge detection
static func _marching_squares_optimized(bitmap: BitMap) -> Array[PackedVector2Array]:
	var size := bitmap.get_size()
	var contours: Array[PackedVector2Array] = []

	# Early exit for empty images
	if size.x == 0 or size.y == 0:
		return contours

	# Create visited bitmap to track processed cells
	# Note: This persists across all contours to prevent re-processing shared edges
	var visited := {}  # Use dictionary with integer keys for speed

	# Single pass: Find all starting points at once
	var edge_points := []

	# Scan only the perimeter first (most edge pixels are on boundaries)
	for x in range(size.x):
		if bitmap.get_bit(x, 0):
			edge_points.append(Vector2i(x, 0))
		if size.y > 1 and bitmap.get_bit(x, size.y - 1):
			edge_points.append(Vector2i(x, size.y - 1))

	for y in range(1, size.y - 1):
		if bitmap.get_bit(0, y):
			edge_points.append(Vector2i(0, y))
		if size.x > 1 and bitmap.get_bit(size.x - 1, y):
			edge_points.append(Vector2i(size.x - 1, y))

	# Then scan interior with adaptive step size to catch thin features
	for y in range(1, size.y - 1):
		# Use adaptive scanning: step=2 normally, but step=1 near detected edges
		var x := 1
		while x < size.x - 1:
			if bitmap.get_bit(x, y) and _is_edge_pixel_fast(bitmap, x, y, size):
				edge_points.append(Vector2i(x, y))
				# Switch to step=1 for next few pixels to catch thin features
				x += 1
			else:
				# No edge here, can skip ahead
				x += 2

	# Process each edge point
	for point in edge_points:
		# Bounds check: Can't create cell from pixels at position 0
		if point.x == 0 or point.y == 0:
			continue

		var cell_x: int = point.x - 1
		var cell_y: int = point.y - 1

		# Check if this cell has already been processed
		var cell_key := _pack_key(cell_x, cell_y)
		if visited.has(cell_key):
			continue

		# Trace the contour from this cell
		var contour := _trace_contour_optimized(bitmap, cell_x, cell_y, size, visited)
		if contour.size() >= 3:  # Minimum valid closed contour (triangle)
			# Ensure clockwise winding order (CW = solid, CCW = hole)
			_normalize_winding_order(contour)
			contours.append(contour)

	return contours


## Normalize contour to clockwise winding order using shoelace formula
static func _normalize_winding_order(contour: PackedVector2Array) -> void:
	if contour.size() < 3:
		return

	# Calculate signed area using shoelace formula
	# Positive area = counter-clockwise, Negative = clockwise
	var signed_area := 0.0
	var n := contour.size()
	for i in range(n):
		var j := (i + 1) % n
		signed_area += contour[i].x * contour[j].y
		signed_area -= contour[j].x * contour[i].y

	# If counter-clockwise (positive area), reverse to make clockwise
	if signed_area > 0:
		contour.reverse()


## Fast edge pixel check (inline for performance)
static func _is_edge_pixel_fast(bitmap: BitMap, x: int, y: int, size: Vector2i) -> bool:
	# Check 4-neighbors in one pass
	return (x > 0 and not bitmap.get_bit(x - 1, y)) or \
		   (x < size.x - 1 and not bitmap.get_bit(x + 1, y)) or \
		   (y > 0 and not bitmap.get_bit(x, y - 1)) or \
		   (y < size.y - 1 and not bitmap.get_bit(x, y + 1))


## Optimized contour tracing with integer key tracking
static func _trace_contour_optimized(bitmap: BitMap, start_x: int, start_y: int, size: Vector2i, visited: Dictionary) -> PackedVector2Array:
	var contour := PackedVector2Array()
	var x := start_x
	var y := start_y

	# Use pre-allocated capacity hint
	contour.resize(0)  # Clear but keep capacity

	var start_key := _pack_key(x, y)
	var iterations := 0
	var max_iterations := size.x * size.y  # Safety limit (reduced from 4x)

	while iterations < max_iterations:
		iterations += 1

		# Pack coordinates into single integer for fast lookup
		var cell_key := _pack_key(x, y)

		# Check if we've completed the loop
		if iterations > 1 and cell_key == start_key:
			break

		# Mark cell as visited
		visited[cell_key] = true

		# Get marching squares configuration
		var config := _get_config_fast(bitmap, x, y, size)

		# Skip empty or full cells
		if config == 0 or config == 15:
			break

		# Get edges for this configuration
		var edges: Array = MARCHING_SQUARES_TABLE[config]
		if edges.is_empty():
			break

		# Process first edge pair only (avoid complex saddle point logic)
		var edge_pair = edges[0]
		if edge_pair.size() >= 2:
			# Add edge points
			var p1 := _get_edge_point_fast(x, y, edge_pair[0])
			var p2 := _get_edge_point_fast(x, y, edge_pair[1])

			# Add points efficiently
			if contour.is_empty():
				contour.append(p1)
				contour.append(p2)
			else:
				# Only add the connecting point
				var last := contour[contour.size() - 1]
				if last.distance_squared_to(p1) < 0.01:  # Use squared distance
					contour.append(p2)
				elif last.distance_squared_to(p2) < 0.01:
					contour.append(p1)
				else:
					# Disconnected - shouldn't happen in valid contour
					break

			# Move to next cell based on exit edge
			var exit_edge = edge_pair[1]
			match exit_edge:
				EDGE_TOP:    y -= 1
				EDGE_RIGHT:  x += 1
				EDGE_BOTTOM: y += 1
				EDGE_LEFT:   x -= 1
				_: break
		else:
			break

	# Remove duplicate end point if it exists
	if contour.size() > 1 and contour[contour.size() - 1].distance_squared_to(contour[0]) < 0.01:
		contour.remove_at(contour.size() - 1)

	return contour


## Pack x,y coordinates into a single integer for fast dictionary lookup
static func _pack_key(x: int, y: int) -> int:
	# Assumes coordinates are < 65536 (which is reasonable for images)
	return (x << 16) | (y & 0xFFFF)


## Fast configuration calculation with cached bounds checking
static func _get_config_fast(bitmap: BitMap, x: int, y: int, size: Vector2i) -> int:
	var config := 0

	# Inline the checks for speed
	# Bottom-left (bit 0)
	if y + 1 < size.y and x >= 0 and x < size.x and bitmap.get_bit(x, y + 1):
		config |= 1
	# Bottom-right (bit 1)
	if y + 1 < size.y and x + 1 < size.x and bitmap.get_bit(x + 1, y + 1):
		config |= 2
	# Top-right (bit 2)
	if y >= 0 and y < size.y and x + 1 < size.x and bitmap.get_bit(x + 1, y):
		config |= 4
	# Top-left (bit 3)
	if y >= 0 and y < size.y and x >= 0 and x < size.x and bitmap.get_bit(x, y):
		config |= 8

	return config


## Fast edge point calculation (inline the common operations)
static func _get_edge_point_fast(cell_x: int, cell_y: int, edge: int) -> Vector2:
	match edge:
		EDGE_TOP:    return Vector2(cell_x + 0.5, cell_y)
		EDGE_RIGHT:  return Vector2(cell_x + 1.0, cell_y + 0.5)
		EDGE_BOTTOM: return Vector2(cell_x + 0.5, cell_y + 1.0)
		EDGE_LEFT:   return Vector2(cell_x, cell_y + 0.5)
		_:           return Vector2(cell_x + 0.5, cell_y + 0.5)
