@tool
extends CutoutContourAlgorithm
class_name CutoutContourMarchingSquares

## Marching squares algorithm for extracting contours from images.
## Supports multiple disconnected shapes by using a fill bitmap to track visited regions.
##
## WINDING ORDER: The winding order depends on the lookup table configuration.
## May need verification to ensure it produces clockwise (CW) polygons consistent
## with Godot's convention where CW = solid and CCW = hole.

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


func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	# Prepare image for BitMap (must be LA8 and uncompressed)
	var converted_image := image.duplicate()
	if converted_image.is_compressed():
		converted_image.decompress()
	converted_image.convert(Image.FORMAT_LA8)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(converted_image, alpha_threshold)

	return _marching_squares_all(bitmap)


## Extract all contours from bitmap using marching squares
static func _marching_squares_all(bitmap: BitMap) -> Array[PackedVector2Array]:
	var size := bitmap.get_size()
	var contours: Array[PackedVector2Array] = []

	# Create a fill bitmap to track visited pixels
	var fill_bitmap := BitMap.new()
	fill_bitmap.create(size)

	# Scan for unvisited opaque edge pixels
	for y in range(size.y):
		for x in range(size.x):
			# Skip if not opaque or already visited
			if not bitmap.get_bit(x, y) or fill_bitmap.get_bit(x, y):
				continue

			# Check if this is an edge pixel
			if not _is_edge_pixel(bitmap, x, y, size):
				continue

			# Trace the contour from this edge pixel
			var contour := _trace_contour(bitmap, x, y, size)
			if contour.size() > 2:  # Only add valid contours
				contours.append(contour)

			# Mark all pixels in this connected region as visited
			_flood_fill(bitmap, fill_bitmap, x, y, size)

	return contours


## Check if a pixel is on the edge of an opaque region
static func _is_edge_pixel(bitmap: BitMap, x: int, y: int, size: Vector2i) -> bool:
	# A pixel is an edge if it's opaque and has at least one transparent neighbor
	if not bitmap.get_bit(x, y):
		return false

	# Check 4-connected neighbors
	if x > 0 and not bitmap.get_bit(x - 1, y):
		return true
	if x < size.x - 1 and not bitmap.get_bit(x + 1, y):
		return true
	if y > 0 and not bitmap.get_bit(x, y - 1):
		return true
	if y < size.y - 1 and not bitmap.get_bit(x, y + 1):
		return true

	return false


## Trace a single contour using marching squares
static func _trace_contour(bitmap: BitMap, start_x: int, start_y: int, size: Vector2i) -> PackedVector2Array:
	var contour := PackedVector2Array()
	var visited_cells := {}  # Track visited marching square cells to detect completion

	# Start from the cell to the left and above the edge pixel
	var x := start_x - 1
	var y := start_y - 1

	var max_steps := size.x * size.y * 4  # Safety limit
	var steps := 0

	while steps < max_steps:
		steps += 1

		# Check if we've visited this cell before
		var cell_key := "%d,%d" % [x, y]
		if visited_cells.has(cell_key):
			break  # Contour is complete
		visited_cells[cell_key] = true

		# Get the marching squares configuration for this cell
		var config := _get_marching_square_config(bitmap, x, y, size)

		# Get edges for this configuration
		var edges: Array = MARCHING_SQUARES_TABLE[config]
		if edges.is_empty():
			break  # No edges to follow

		# Add edge points to contour
		for edge_pair in edges:
			if edge_pair.size() >= 2:
				var p1 := _get_edge_point(x, y, edge_pair[0])
				var p2 := _get_edge_point(x, y, edge_pair[1])

				# Add points in order (we may need to handle direction)
				if contour.is_empty():
					contour.append(p1)
					contour.append(p2)
				else:
					# Find which point connects to our last point
					var last := contour[contour.size() - 1]
					if last.distance_to(p1) < 0.1:
						contour.append(p2)
					elif last.distance_to(p2) < 0.1:
						contour.append(p1)
					else:
						# Start new segment if disconnected
						contour.append(p1)
						contour.append(p2)

		# Move to next cell based on the last edge
		if edges.size() > 0 and edges[0].size() >= 2:
			var exit_edge: int = edges[0][1]  # Use first edge pair's exit
			if edges.size() > 1 and contour.size() > 1:
				# For saddle points, choose the edge that connects
				for edge_pair in edges:
					if edge_pair.size() >= 2:
						var p := _get_edge_point(x, y, edge_pair[1])
						if contour[contour.size() - 1].distance_to(p) < 0.1:
							exit_edge = edge_pair[1]
							break

			# Move to adjacent cell based on exit edge
			match exit_edge:
				EDGE_TOP:
					y -= 1
				EDGE_RIGHT:
					x += 1
				EDGE_BOTTOM:
					y += 1
				EDGE_LEFT:
					x -= 1
		else:
			break

	# Clean up duplicate points at the end
	while contour.size() > 1 and contour[contour.size() - 1].distance_to(contour[0]) < 0.1:
		contour.remove_at(contour.size() - 1)

	return contour


## Get marching squares configuration for a 2x2 cell
static func _get_marching_square_config(bitmap: BitMap, x: int, y: int, size: Vector2i) -> int:
	var config := 0

	# Check four corners of the cell (2x2 grid)
	# Bottom-left (bit 0)
	if _is_pixel_set(bitmap, x, y + 1, size):
		config |= 1
	# Bottom-right (bit 1)
	if _is_pixel_set(bitmap, x + 1, y + 1, size):
		config |= 2
	# Top-right (bit 2)
	if _is_pixel_set(bitmap, x + 1, y, size):
		config |= 4
	# Top-left (bit 3)
	if _is_pixel_set(bitmap, x, y, size):
		config |= 8

	return config


## Safely check if a pixel is set (with bounds checking)
static func _is_pixel_set(bitmap: BitMap, x: int, y: int, size: Vector2i) -> bool:
	if x < 0 or x >= size.x or y < 0 or y >= size.y:
		return false
	return bitmap.get_bit(x, y)


## Get the position of an edge point
static func _get_edge_point(cell_x: int, cell_y: int, edge: int) -> Vector2:
	match edge:
		EDGE_TOP:
			return Vector2(cell_x + 0.5, cell_y)
		EDGE_RIGHT:
			return Vector2(cell_x + 1.0, cell_y + 0.5)
		EDGE_BOTTOM:
			return Vector2(cell_x + 0.5, cell_y + 1.0)
		EDGE_LEFT:
			return Vector2(cell_x, cell_y + 0.5)
		_:
			return Vector2(cell_x + 0.5, cell_y + 0.5)


## Flood fill to mark all connected pixels as visited
static func _flood_fill(bitmap: BitMap, fill_bitmap: BitMap, start_x: int, start_y: int, size: Vector2i) -> void:
	var stack := [Vector2i(start_x, start_y)]

	while not stack.is_empty():
		var pos := stack.pop_back() as Vector2i
		var x := pos.x
		var y := pos.y

		# Skip if out of bounds or already filled
		if x < 0 or x >= size.x or y < 0 or y >= size.y:
			continue
		if fill_bitmap.get_bit(x, y):
			continue
		if not bitmap.get_bit(x, y):
			continue

		# Mark as filled
		fill_bitmap.set_bit(x, y, true)

		# Add 4-connected neighbors to stack
		stack.append(Vector2i(x - 1, y))
		stack.append(Vector2i(x + 1, y))
		stack.append(Vector2i(x, y - 1))
		stack.append(Vector2i(x, y + 1))