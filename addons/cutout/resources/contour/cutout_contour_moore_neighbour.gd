@tool
class_name CutoutContourMooreNeighbour
extends CutoutContourAlgorithm
## Moore Neighbourhood contour tracing algorithm for extracting polygon boundaries from textures.
##
## WINDING ORDER: Produces clockwise (CW) polygons, consistent with Godot's
## convention where CW = solid and CCW = hole.

const DISPLAY_NAME := "Moore Neighbour"

# Algorithm type constant (must match Rust ContourAlgorithm enum)
const ALGORITHM_TYPE := 0  # ContourAlgorithm::MooreNeighbour

# Moore neighborhood directions (clockwise from west)
const DIRECTIONS = [
	Vector2i(-1, 0),  # 0: W
	Vector2i(-1, -1), # 1: NW
	Vector2i(0, -1),  # 2: N
	Vector2i(1, -1),  # 3: NE
	Vector2i(1, 0),   # 4: E
	Vector2i(1, 1),   # 5: SE
	Vector2i(0, 1),   # 6: S
	Vector2i(-1, 1)   # 7: SW
]



## Virtual. Concrete implementation of calculate_boundary
func _calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	# Convert max_resolution int to Vector2 (0 = no limit = Vector2(-1, -1))
	var max_res_vec := Vector2(-1, -1) if max_resolution == 0 else Vector2(max_resolution, max_resolution)

	# Call Rust batch processor with single image
	var results = CutoutContourProcessor.calculate_batch_uniform(
		[image],           # Single image as batch of 1
		ALGORITHM_TYPE,    # Enum value
		alpha_threshold,   # From base class
		max_res_vec        # From base class (converted to Vector2)
	)

	# Extract first (and only) result
	return results[0] if results.size() > 0 else []
