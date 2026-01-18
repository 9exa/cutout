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
	
	# Loop through the grid cells
	for y in range(size.y - 1):
		for x in range(size.x - 1):
			
			# Calculate 4-bit index based on corners
			var cell_idx := 0
			if bitmap.get_bit(x, y):           cell_idx |= 8 # Top-Left
			if bitmap.get_bit(x + 1, y):       cell_idx |= 4 # Top-Right
			if bitmap.get_bit(x + 1, y + 1):   cell_idx |= 2 # Bottom-Right
			if bitmap.get_bit(x, y + 1):       cell_idx |= 1 # Bottom-Left
			
			var edges := LOOKUP_BITS[cell_idx]
			if edges == 0xFFFF: continue
			
			# Process segments (up to 2 per cell)
			for i in range(2):
				var e1 := (edges >> (i * 8)) & 0xF
				var e2 := (edges >> (i * 8 + 4)) & 0xF
				
				if e1 == 0xF: break 
				
				result.append(_get_edge_pos(x, y, e1))
				result.append(_get_edge_pos(x, y, e2))
				
	return result

static func _get_edge_pos(x: int, y: int, edge: int) -> Vector2:
	match edge:
		0: return Vector2(x + 0.5, y)       # Top
		1: return Vector2(x + 1.0, y + 0.5) # Right
		2: return Vector2(x + 0.5, y + 1.0) # Bottom
		3: return Vector2(x, y + 0.5)       # Left
	return Vector2(x, y)
