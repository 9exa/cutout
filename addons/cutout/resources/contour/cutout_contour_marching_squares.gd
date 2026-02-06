@tool
extends CutoutContourAlgorithm
class_name CutoutContourMarchingSquares

## Marching squares algorithm for extracting contours from images.
##
## WINDING ORDER: CW = solid/filled polygon, CCW = hole.
## This implementation produces CW contours for solid regions.

const DISPLAY_NAME := "Marching Squares"

# Edge indices (clockwise around cell)
const EDGE_TOP = 0
const EDGE_RIGHT = 1
const EDGE_BOTTOM = 2
const EDGE_LEFT = 3

# Marching squares lookup table
# Cell corners: bit0=top-left, bit1=top-right, bit2=bottom-right, bit3=bottom-left
#
# For CW winding (solid on right side of travel):
# - We trace the boundary with solid pixels on our right
# - Segment goes from one edge midpoint to another
#
# Cell layout:
#   TL---TOP---TR
#   |          |
#  LEFT      RIGHT
#   |          |
#   BL--BOTTOM-BR

const EDGE_TABLE = [
	[],                          # 0:  0000 - empty (no boundary)
	[[EDGE_TOP, EDGE_LEFT]],     # 1:  0001 - TL solid
	[[EDGE_RIGHT, EDGE_TOP]],    # 2:  0010 - TR solid
	[[EDGE_RIGHT, EDGE_LEFT]],   # 3:  0011 - TL+TR solid (top half)
	[[EDGE_BOTTOM, EDGE_RIGHT]], # 4:  0100 - BR solid
	[[EDGE_TOP, EDGE_LEFT], [EDGE_BOTTOM, EDGE_RIGHT]],  # 5: TL+BR saddle
	[[EDGE_BOTTOM, EDGE_TOP]],   # 6:  0110 - TR+BR solid (right half)
	[[EDGE_BOTTOM, EDGE_LEFT]],  # 7:  0111 - TL+TR+BR solid
	[[EDGE_LEFT, EDGE_BOTTOM]],  # 8:  1000 - BL solid
	[[EDGE_TOP, EDGE_BOTTOM]],   # 9:  1001 - TL+BL solid (left half)
	[[EDGE_RIGHT, EDGE_TOP], [EDGE_LEFT, EDGE_BOTTOM]],  # 10: TR+BL saddle
	[[EDGE_RIGHT, EDGE_BOTTOM]], # 11: 1011 - TL+TR+BL solid
	[[EDGE_LEFT, EDGE_RIGHT]],   # 12: 1100 - BR+BL solid (bottom half)
	[[EDGE_LEFT, EDGE_TOP]],     # 13: 1101 - TL+BR+BL solid
	[[EDGE_TOP, EDGE_RIGHT]],    # 14: 1110 - TR+BR+BL solid
	[]                           # 15: 1111 - full (no boundary)
]


func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	var converted := image.duplicate()
	if converted.is_compressed():
		converted.decompress()
	converted.convert(Image.FORMAT_LA8)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(converted, alpha_threshold)

	var size := bitmap.get_size()
	if size.x < 2 or size.y < 2:
		return []

	# Step 1: Generate all edge segments
	var segments := _generate_segments(bitmap, size)
	if segments.is_empty():
		return []

	# Step 2: Chain segments into closed contours
	var contours := _chain_segments(segments)

	return contours


## Generate edge segments for all cells
func _generate_segments(bitmap: BitMap, size: Vector2i) -> Array:
	var segments := []

	# Cells are between pixels, so we iterate to size-1
	for cy in range(size.y - 1):
		for cx in range(size.x - 1):
			var config := _get_config(bitmap, cx, cy)

			# Skip empty and full cells
			if config == 0 or config == 15:
				continue

			# Get edge pairs for this configuration
			var edge_pairs: Array = EDGE_TABLE[config]

			for pair in edge_pairs:
				var p1 := _edge_to_point(cx, cy, pair[0])
				var p2 := _edge_to_point(cx, cy, pair[1])
				segments.append([p1, p2])

	return segments


## Get the 4-bit configuration for a cell
## Cell (cx, cy) has corners at pixels:
##   top-left: (cx, cy), top-right: (cx+1, cy)
##   bottom-left: (cx, cy+1), bottom-right: (cx+1, cy+1)
func _get_config(bitmap: BitMap, cx: int, cy: int) -> int:
	var config := 0
	if bitmap.get_bit(cx, cy):         # top-left
		config |= 1
	if bitmap.get_bit(cx + 1, cy):     # top-right
		config |= 2
	if bitmap.get_bit(cx + 1, cy + 1): # bottom-right
		config |= 4
	if bitmap.get_bit(cx, cy + 1):     # bottom-left
		config |= 8
	return config


## Convert edge index to point coordinate (midpoint of cell edge)
func _edge_to_point(cx: int, cy: int, edge: int) -> Vector2:
	match edge:
		EDGE_TOP:
			return Vector2(cx + 0.5, cy)
		EDGE_RIGHT:
			return Vector2(cx + 1, cy + 0.5)
		EDGE_BOTTOM:
			return Vector2(cx + 0.5, cy + 1)
		EDGE_LEFT:
			return Vector2(cx, cy + 0.5)
	return Vector2(cx + 0.5, cy + 0.5)


## Chain segments into closed contours
func _chain_segments(segments: Array) -> Array[PackedVector2Array]:
	var contours: Array[PackedVector2Array] = []

	if segments.is_empty():
		return contours

	# Build adjacency map: point_key -> list of {segment_idx, is_start}
	var adjacency := {}

	for i in range(segments.size()):
		var seg = segments[i]
		var key0 := _point_key(seg[0])
		var key1 := _point_key(seg[1])

		if not adjacency.has(key0):
			adjacency[key0] = []
		adjacency[key0].append({"idx": i, "start": true})

		if not adjacency.has(key1):
			adjacency[key1] = []
		adjacency[key1].append({"idx": i, "start": false})

	var used := {}

	# Build contours by chaining segments
	for start_idx in range(segments.size()):
		if used.has(start_idx):
			continue

		var contour := PackedVector2Array()
		var seg = segments[start_idx]

		contour.append(seg[0])
		contour.append(seg[1])
		used[start_idx] = true

		var current_point: Vector2 = seg[1]
		var start_point: Vector2 = seg[0]

		# Follow chain until we close or get stuck
		for _iter in range(segments.size()):
			if _points_equal(current_point, start_point):
				break

			var key := _point_key(current_point)
			var found := false

			if adjacency.has(key):
				for entry in adjacency[key]:
					if used.has(entry["idx"]):
						continue

					var next_seg = segments[entry["idx"]]
					var next_point: Vector2

					if entry["start"]:
						next_point = next_seg[1]
					else:
						next_point = next_seg[0]

					contour.append(next_point)
					current_point = next_point
					used[entry["idx"]] = true
					found = true
					break

			if not found:
				break

		# Clean up: remove duplicate closing point
		if contour.size() > 2 and _points_equal(contour[contour.size() - 1], contour[0]):
			contour.remove_at(contour.size() - 1)

		if contour.size() >= 3:
			contours.append(contour)

	return contours


## Hash a point to an integer key
func _point_key(p: Vector2) -> int:
	var x := int(p.x * 2)
	var y := int(p.y * 2)
	return x * 100000 + y


## Check point equality with tolerance
func _points_equal(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) < 0.001
