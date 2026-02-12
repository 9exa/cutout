@tool
class_name CutoutContourMarchingSquares
extends CutoutContourAlgorithm
## Marching Squares algorithm for contour extraction from images.
##
## Uses a segment-based approach: first generates all line segments,
## then chains them into closed contours.

# Algorithm type constant (must match Rust ContourAlgorithm enum)
const ALGORITHM_TYPE := 1  # ContourAlgorithm::MarchingSquares

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
	# Call Rust batch processor with single image
	var results = ContourProcessor.calculate_batch_uniform(
		[image],
		ALGORITHM_TYPE,
		alpha_threshold,
		max_resolution
	)
	return results[0] if results.size() > 0 else []
