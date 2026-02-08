@tool
class_name CutoutContourMarchingSquares
extends CutoutContourAlgorithm
## Marching Squares algorithm for contour extraction from images.
##
## Uses a segment-based approach: first generates all line segments,
## then chains them into closed contours.

# Edge constants for public API (used by tests)
const EDGE_TOP := 0
const EDGE_RIGHT := 1
const EDGE_BOTTOM := 2
const EDGE_LEFT := 3

# Segment lookup table for each of the 16 cases
# Bit order: bit3=TL, bit2=TR, bit1=BR, bit0=BL
# Each entry is an array of segments, where each segment is [edge_a, edge_b]
#
# Cell layout:
#   TL ---TOP--- TR
#   |            |
#  LEFT        RIGHT
#   |            |
#   BL --BOTTOM-- BR
#
const SEGMENT_TABLE := [
	[],                                      # 0:  0000 - empty
	[[EDGE_LEFT, EDGE_BOTTOM]],              # 1:  0001 - BL only
	[[EDGE_BOTTOM, EDGE_RIGHT]],             # 2:  0010 - BR only
	[[EDGE_LEFT, EDGE_RIGHT]],               # 3:  0011 - BL+BR
	[[EDGE_RIGHT, EDGE_TOP]],                # 4:  0100 - TR only
	[[EDGE_LEFT, EDGE_TOP], [EDGE_BOTTOM, EDGE_RIGHT]],  # 5:  0101 - TR+BL (saddle)
	[[EDGE_BOTTOM, EDGE_TOP]],               # 6:  0110 - TR+BR
	[[EDGE_LEFT, EDGE_TOP]],                 # 7:  0111 - TR+BR+BL
	[[EDGE_TOP, EDGE_LEFT]],                 # 8:  1000 - TL only
	[[EDGE_TOP, EDGE_BOTTOM]],               # 9:  1001 - TL+BL
	[[EDGE_TOP, EDGE_RIGHT], [EDGE_LEFT, EDGE_BOTTOM]],  # 10: 1010 - TL+BR (saddle)
	[[EDGE_TOP, EDGE_RIGHT]],                # 11: 1011 - TL+BR+BL
	[[EDGE_RIGHT, EDGE_LEFT]],               # 12: 1100 - TL+TR
	[[EDGE_RIGHT, EDGE_BOTTOM]],             # 13: 1101 - TL+TR+BL
	[[EDGE_BOTTOM, EDGE_LEFT]],              # 14: 1110 - TL+TR+BR
	[],                                      # 15: 1111 - full
]


func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	if image == null:
		return []

	var width := image.get_width()
	var height := image.get_height()

	if width == 0 or height == 0:
		return []

	# Create bitmap from image
	var bitmap := _create_bitmap(image)

	# Phase 1: Generate all segments
	var segments := _generate_segments(bitmap, width, height)

	if segments.is_empty():
		return []

	# Phase 2: Chain segments into contours
	var contours := _chain_segments(segments)

	# Sort by size (largest first)
	contours.sort_custom(func(a, b): return a.size() > b.size())

	return contours


## Create BitMap from image, handling compression
func _create_bitmap(image: Image) -> BitMap:
	var converted := image.duplicate()

	if converted.is_compressed():
		converted.decompress()

	converted.convert(Image.FORMAT_LA8)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(converted, alpha_threshold)

	return bitmap


## Generate all line segments from the bitmap
func _generate_segments(bitmap: BitMap, width: int, height: int) -> Array:
	var segments := []

	# Iterate through all cells
	# Cell (x, y) has corners at pixels (x,y), (x+1,y), (x+1,y+1), (x,y+1)
	for cy in range(height):
		for cx in range(width):
			var case_index := _get_case(bitmap, cx, cy, width, height)

			if case_index == 0 or case_index == 15:
				continue

			var cell_segments: Array = SEGMENT_TABLE[case_index]

			for seg in cell_segments:
				var p1 := _edge_to_point(cx, cy, seg[0])
				var p2 := _edge_to_point(cx, cy, seg[1])
				segments.append([p1, p2])

	return segments


## Get the 4-bit case index for a cell
## Bit order: bit3=TL, bit2=TR, bit1=BR, bit0=BL
func _get_case(bitmap: BitMap, cx: int, cy: int, width: int, height: int) -> int:
	var tl := _get_pixel(bitmap, cx, cy, width, height)
	var tr := _get_pixel(bitmap, cx + 1, cy, width, height)
	var br := _get_pixel(bitmap, cx + 1, cy + 1, width, height)
	var bl := _get_pixel(bitmap, cx, cy + 1, width, height)

	var case_index := 0
	if tl: case_index |= 8
	if tr: case_index |= 4
	if br: case_index |= 2
	if bl: case_index |= 1

	return case_index


## Get pixel value (false if out of bounds)
func _get_pixel(bitmap: BitMap, x: int, y: int, width: int, height: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	return bitmap.get_bit(x, y)


## Convert edge to point coordinate (midpoint of edge)
func _edge_to_point(cx: int, cy: int, edge: int) -> Vector2:
	match edge:
		EDGE_TOP:
			return Vector2(cx + 0.5, cy)
		EDGE_RIGHT:
			return Vector2(cx + 1.0, cy + 0.5)
		EDGE_BOTTOM:
			return Vector2(cx + 0.5, cy + 1.0)
		EDGE_LEFT:
			return Vector2(cx, cy + 0.5)
	return Vector2(cx, cy)


## Chain segments into closed contours
func _chain_segments(segments: Array) -> Array[PackedVector2Array]:
	if segments.is_empty():
		return []

	# Build adjacency map: point_key -> [connected point keys]
	# Using keys throughout for consistent comparison
	var adjacency := {}

	for seg in segments:
		var p1: Vector2 = seg[0]
		var p2: Vector2 = seg[1]

		var k1 := _point_key(p1)
		var k2 := _point_key(p2)

		if not adjacency.has(k1):
			adjacency[k1] = []
		if not adjacency.has(k2):
			adjacency[k2] = []

		adjacency[k1].append(k2)
		adjacency[k2].append(k1)

	var contours: Array[PackedVector2Array] = []

	# Extract contours by following adjacency chains
	while not adjacency.is_empty():
		# Start from any point that still has connections
		var start_key: String = adjacency.keys()[0]
		var start_point := _key_to_point(start_key)

		var contour := PackedVector2Array()
		contour.append(start_point)

		var prev_key: String = ""
		var current_key: String = start_key

		# Follow the chain until we return to start or run out of connections
		# Limit iterations to total number of segments (each segment visited once)
		var max_iter := segments.size() + 1

		for iter in range(max_iter):
			if not adjacency.has(current_key):
				break

			var neighbors: Array = adjacency[current_key]

			if neighbors.is_empty():
				adjacency.erase(current_key)
				break

			# Find next point: pick neighbor that isn't where we came from
			var next_key: String = ""
			var next_idx := -1

			for i in range(neighbors.size()):
				if neighbors[i] != prev_key:
					next_key = neighbors[i]
					next_idx = i
					break

			# If all neighbors are prev (shouldn't happen), just take first
			if next_key == "":
				next_key = neighbors[0]
				next_idx = 0

			# Remove this connection (both directions)
			neighbors.remove_at(next_idx)
			if neighbors.is_empty():
				adjacency.erase(current_key)

			# Remove reverse connection
			if adjacency.has(next_key):
				var reverse: Array = adjacency[next_key]
				var rev_idx := reverse.find(current_key)
				if rev_idx >= 0:
					reverse.remove_at(rev_idx)
				if reverse.is_empty():
					adjacency.erase(next_key)

			# Check if we've closed the loop
			if next_key == start_key:
				break

			# Add next point to contour and continue
			contour.append(_key_to_point(next_key))
			prev_key = current_key
			current_key = next_key

		if contour.size() >= 3:
			contours.append(contour)

	return contours


## Create a string key from a point (for dictionary lookups)
func _point_key(p: Vector2) -> String:
	# Multiply by 100 to preserve 2 decimal places of precision while avoiding
	# floating point comparison issues. This handles sub-pixel edge positions
	# from marching squares (e.g., 0.5, 1.5, etc.) reliably.
	return "%d,%d" % [int(p.x * 100), int(p.y * 100)]


## Convert key back to point
func _key_to_point(key: String) -> Vector2:
	var parts := key.split(",")
	return Vector2(int(parts[0]) / 100.0, int(parts[1]) / 100.0)
