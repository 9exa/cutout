class_name CutoutContourMooreNeighbour
extends CutoutContourAlgorithm
## Algorithms for producing CutoutContourData fromtextures.

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



# Helper function to check if bit is set and in bounds
static func _is_solid(bitmap: BitMap, pos: Vector2i, width: int, height: int) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false
	return bitmap.get_bit(pos.x, pos.y)


# Moore neighborhood contour following algorithm after having already calculated the bitmap
static func _extract_contour(bitmap: BitMap) -> PackedVector2Array:
	var width := bitmap.get_size().x
	var height := bitmap.get_size().y

	# Find the topmost-leftmost set bit as starting point
	var start_pixel := Vector2i(-1, -1)
	for y in range(height):
		for x in range(width):
			if bitmap.get_bit(x, y):
				# Check if this is an edge pixel
				var is_edge := false
				if x == 0 or not bitmap.get_bit(x-1, y):
					is_edge = true
				elif y == 0 or not bitmap.get_bit(x, y-1):
					is_edge = true

				if is_edge:
					start_pixel = Vector2i(x, y)
					break
		if start_pixel.x != -1:
			break

	if start_pixel.x == -1:
		return PackedVector2Array()

	var contour := PackedVector2Array()
	var current := start_pixel
	var entered_from := 0  # Initially entered from west
	var contour_started := false

	# Main contour tracing loop
	var max_points := width * height  # Safety limit
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
			var neighbor: Vector2i = current + DIRECTIONS[dir]

			if _is_solid(bitmap, neighbor, width, height):
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



## Virtual. Concrete implementation of calculate_boundary
func _calculate_boundary(image: Image) -> PackedVector2Array:
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_threshold)

	return [_extract_contour(bitmap)]
