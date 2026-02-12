@tool
extends Node

## Tests for CutoutContourMooreNeighbour algorithm

var CutoutContourMooreNeighbour = load("res://addons/cutout/resources/contour/cutout_contour_moore_neighbour.gd")

func test_moore_neighbour_initialization():
	var algorithm = CutoutContourMooreNeighbour.new()
	assert(algorithm != null, "Algorithm should be created")
	assert(algorithm.alpha_threshold == 0.5, "Default alpha threshold should be 0.5")

func test_moore_neighbour_null_image():
	var algorithm = CutoutContourMooreNeighbour.new()
	var result = algorithm.calculate_boundary(null)
	assert(result.size() == 0, "Null image should return empty array")

func test_moore_neighbour_empty_image():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fully transparent

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return array with one contour")
	assert(result[0].size() == 0, "Fully transparent image should return empty contour")

func test_moore_neighbour_single_pixel():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color(1, 1, 1, 1))  # Single opaque pixel

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return array with one contour")
	assert(result[0].size() > 0, "Single pixel should generate contour points")
	assert(result[0][0] == Vector2(1, 1), "Should start at the pixel position")

func test_moore_neighbour_simple_square():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a 2x2 solid square
	for y in range(1, 3):
		for x in range(1, 3):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return array with one contour")
	assert(result[0].size() > 0, "Square should generate contour points")
	# Moore neighborhood should trace the perimeter
	assert(result[0].size() >= 4, "Square perimeter should have at least 4 points")

func test_moore_neighbour_alpha_threshold():
	var algorithm = CutoutContourMooreNeighbour.new()
	algorithm.alpha_threshold = 0.8  # High threshold

	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color(1, 1, 1, 0.5))  # Semi-transparent

	var result = algorithm.calculate_boundary(image)
	assert(result[0].size() == 0, "Semi-transparent below threshold should not create contour")

	# Lower threshold
	algorithm.alpha_threshold = 0.3
	result = algorithm.calculate_boundary(image)
	assert(result[0].size() > 0, "Semi-transparent above threshold should create contour")

func test_is_solid_static_helper():
	# Test the _is_solid static helper function
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(5, 5))
	bitmap.set_bit(2, 2, true)

	assert(
		CutoutContourMooreNeighbour._is_solid(bitmap, Vector2i(2, 2), 5, 5),
		"Should detect solid pixel"
	)
	assert(
		not CutoutContourMooreNeighbour._is_solid(bitmap, Vector2i(0, 0), 5, 5),
		"Should detect empty pixel"
	)
	assert(
		not CutoutContourMooreNeighbour._is_solid(bitmap, Vector2i(-1, 0), 5, 5),
		"Out of bounds should return false"
	)
	assert(
		not CutoutContourMooreNeighbour._is_solid(bitmap, Vector2i(10, 10), 5, 5),
		"Out of bounds should return false"
	)

func test_extract_contour_with_bitmap():
	# Test the static _extract_contour function
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(5, 5))

	# Create a small L-shape
	bitmap.set_bit(1, 1, true)
	bitmap.set_bit(1, 2, true)
	bitmap.set_bit(2, 2, true)

	var result = CutoutContourMooreNeighbour._extract_contour(bitmap)
	assert(result.size() > 0, "L-shape should generate contour")
	assert(result[0] == Vector2(1, 1), "Should start from topmost-leftmost pixel")

func test_moore_neighbour_horizontal_line():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(6, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a horizontal line
	for x in range(1, 5):
		image.set_pixel(x, 1, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return one contour")
	assert(result[0].size() > 0, "Horizontal line should generate contour")

func test_moore_neighbour_vertical_line():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(3, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a vertical line
	for y in range(1, 5):
		image.set_pixel(1, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return one contour")
	assert(result[0].size() > 0, "Vertical line should generate contour")

func test_moore_neighbour_diagonal():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a diagonal line
	for i in range(1, 5):
		image.set_pixel(i, i, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return one contour")
	assert(result[0].size() > 0, "Diagonal line should generate contour")

func test_moore_neighbour_circle_approximation():
	var algorithm = CutoutContourMooreNeighbour.new()
	var image = Image.create(11, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a filled circle approximation
	var center = Vector2(5, 5)
	var radius = 3.0
	for y in range(11):
		for x in range(11):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 1, "Should return one contour")
	assert(result[0].size() > 0, "Circle should generate contour")
	# The contour should trace around the perimeter
	assert(result[0].size() >= 8, "Circle perimeter should have multiple points")

func test_moore_neighbour_empty_bitmap():
	# Test edge case with completely empty bitmap
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(10, 10))

	var result = CutoutContourMooreNeighbour._extract_contour(bitmap)
	assert(result.size() == 0, "Empty bitmap should return empty contour")

func test_moore_directions_constant():
	# Verify the DIRECTIONS constant has expected values
	assert(
		CutoutContourMooreNeighbour.DIRECTIONS.size() == 8,
		"Should have 8 Moore directions"
	)
	assert(
		CutoutContourMooreNeighbour.DIRECTIONS[0] == Vector2i(-1, 0),
		"First direction should be West"
	)
	assert(
		CutoutContourMooreNeighbour.DIRECTIONS[4] == Vector2i(1, 0),
		"Fifth direction should be East"
	)
