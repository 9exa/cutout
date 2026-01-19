@tool
extends CutoutContourAlgorithm
class_name CutoutContourMarchingSquares


# Edge Indices
const EDGE_TOP    = 0x0
const EDGE_RIGHT  = 0x1
const EDGE_BOTTOM = 0x2
const EDGE_LEFT   = 0x3
const EDGE_NULL   = 0xF

# Each int stores two segments: (edgeA << 0 | edgeB << 4) | (edgeC << 8 | edgeD << 12)
const LOOKUP_BITS: PackedInt32Array = [
	0xFFFF, 0xFF32, 0xFF12, 0xFF13,
	0xFF01, 0x3210, 0xFF02, 0xFF03,
	0xFF03, 0xFF02, 0x2130, 0xFF01,
	0xFF13, 0xFF12, 0xFF32, 0xFFFF
]

func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	# 1. Prepare image for BitMap (must be LA8 and uncompressed)
	var converted_image := image.duplicate()
	if converted_image.is_compressed():
		converted_image.decompress()
	converted_image.convert(Image.FORMAT_LA8)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(converted_image, alpha_threshold)

	return [_marching_squares(bitmap)]

static func _marching_squares(bitmap: BitMap) -> PackedVector2Array:
	var size := bitmap.get_size()
	var result := PackedVector2Array()
	var visited := {}  # Track visited cells to avoid duplicate contours

	# Find the topmost-leftmost opaque pixel as starting point
	var start_pos := Vector2i(-1, -1)
	for y in range(size.y):
		for x in range(size.x):
			if bitmap.get_bit(x, y):
				start_pos = Vector2i(x, y)
				break
		if start_pos.x != -1:
			break

	if start_pos.x == -1:
		return result

	# Trace contours starting from the first opaque pixel
	for start_y in range(size.y):
		for start_x in range(size.x):
			if not bitmap.get_bit(start_x, start_y):
				continue

			# Check if we've already traced from this cell
			var cell_key = "%d,%d" % [start_x, start_y]
			if visited.has(cell_key):
				continue

			# Start marching squares from this cell
			var contour = _march_square(bitmap, start_x, start_y, size)
			if contour.size() > 0:
				result.append_array(contour)
				visited[cell_key] = true

	return result


# Trace a single contour using marching squares with proper path following
static func _march_square(bitmap: BitMap, start_x: int, start_y: int, size: Vector2i) -> PackedVector2Array:
	var contour := PackedVector2Array()
	var x := start_x
	var y := start_y
	var prev_dir := 0  # Direction we entered from: 0=from left, 1=from top, 2=from right, 3=from bottom
	var max_points := size.x * size.y * 8

	# Add initial point at center of starting cell
	contour.append(Vector2(x + 0.5, y + 0.5))

	var steps := 0
	while steps < max_points:
		steps += 1

		# Get the 4 corners of the current cell
		var tl := bitmap.get_bit(x, y) if x >= 0 and y >= 0 else false             # Bit 3
		var tr := bitmap.get_bit(x + 1, y) if (x + 1 < size.x and y >= 0) else false      # Bit 2
		var br := bitmap.get_bit(x + 1, y + 1) if (x + 1 < size.x and y + 1 < size.y) else false # Bit 1
		var bl := bitmap.get_bit(x, y + 1) if (x >= 0 and y + 1 < size.y) else false      # Bit 0

		# Calculate cell index
		var cell_idx := 0
		if tl: cell_idx |= 8
		if tr: cell_idx |= 4
		if br: cell_idx |= 2
		if bl: cell_idx |= 1

		# Get the edge configuration for this cell
		var edges := LOOKUP_BITS[cell_idx]

		# Extract the two edges from the lookup table for this entry direction
		var e1 := (edges >> 0) & 0xF
		var e2 := (edges >> 4) & 0xF

		# Add the two edge midpoints
		if e1 != 0xF:
			contour.append(_get_edge_pos(x, y, e1))
		if e2 != 0xF:
			contour.append(_get_edge_pos(x, y, e2))

		# Determine next cell to move to based on the exit edge
		var next_x := x
		var next_y := y
		var next_dir := prev_dir

		if e2 == EDGE_TOP:
			next_y -= 1
			next_dir = 1  # Entering from bottom
		elif e2 == EDGE_RIGHT:
			next_x += 1
			next_dir = 0  # Entering from left
		elif e2 == EDGE_BOTTOM:
			next_y += 1
			next_dir = 3  # Entering from top
		elif e2 == EDGE_LEFT:
			next_x -= 1
			next_dir = 2  # Entering from right

		# Check if we've returned to start
		if next_x == start_x and next_y == start_y:
			break

		# Check bounds
		if next_x < 0 or next_x >= size.x or next_y < 0 or next_y >= size.y:
			break

		x = next_x
		y = next_y
		prev_dir = next_dir

	# Remove duplicate points
	while contour.size() > 1 and contour[contour.size() - 1].distance_to(contour[0]) < 0.1:
		contour.remove_at(contour.size() - 1)

	return contour

static func _get_edge_pos(x: int, y: int, edge: int) -> Vector2:
	match edge:
		0: return Vector2(x + 0.5, y)       # Top
		1: return Vector2(x + 1.0, y + 0.5) # Right
		2: return Vector2(x + 0.5, y + 1.0) # Bottom
		3: return Vector2(x, y + 0.5)       # Left
	return Vector2(x, y)
