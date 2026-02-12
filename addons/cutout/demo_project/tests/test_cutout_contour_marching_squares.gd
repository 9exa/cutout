extends Node

## Tests for CutoutContourMarchingSquares algorithm

var CutoutContourMarchingSquares = load("res://addons/cutout/resources/contour/cutout_contour_marching_squares.gd")

func test_marching_squares_initialization():
	var algorithm = CutoutContourMarchingSquares.new()
	assert(algorithm != null, "Algorithm should be created")
	assert(algorithm.alpha_threshold == 0.5, "Default alpha threshold should be 0.5")

func test_marching_squares_null_image():
	var algorithm = CutoutContourMarchingSquares.new()
	var result = algorithm.calculate_boundary(null)
	assert(result.size() == 0, "Null image should return empty array")

func test_marching_squares_empty_image():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fully transparent

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 0, "Fully transparent image should return empty contour")

func test_marching_squares_single_pixel():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fill with transparent
	image.set_pixel(1, 1, Color(1, 1, 1, 1))  # Single opaque pixel in center

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Single pixel should generate contour")

func test_marching_squares_simple_square():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fill with transparent

	# Create a 2x2 solid square in the middle
	for y in range(1, 3):
		for x in range(1, 3):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "2x2 square should generate at least one contour")
	assert(result[0].size() >= 3, "Contour should have at least 3 points")

func test_marching_squares_alpha_threshold():
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.alpha_threshold = 0.8  # High threshold

	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(1, 1, Color(1, 1, 1, 0.5))  # Semi-transparent pixel

	var result = algorithm.calculate_boundary(image)
	assert(result.size() == 0, "Semi-transparent pixel below threshold should not create contour")

	# Now with lower threshold
	algorithm.alpha_threshold = 0.3
	result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Semi-transparent pixel above threshold should create contour")

func test_edge_to_point():
	var algorithm = CutoutContourMarchingSquares.new()

	# EDGE_TOP = 0, EDGE_RIGHT = 1, EDGE_BOTTOM = 2, EDGE_LEFT = 3
	var top = algorithm._edge_to_point(0, 0, CutoutContourMarchingSquares.EDGE_TOP)
	assert(top == Vector2(0.5, 0), "Top edge should be at middle of top")

	var right = algorithm._edge_to_point(0, 0, CutoutContourMarchingSquares.EDGE_RIGHT)
	assert(right == Vector2(1.0, 0.5), "Right edge should be at middle of right")

	var bottom = algorithm._edge_to_point(0, 0, CutoutContourMarchingSquares.EDGE_BOTTOM)
	assert(bottom == Vector2(0.5, 1.0), "Bottom edge should be at middle of bottom")

	var left = algorithm._edge_to_point(0, 0, CutoutContourMarchingSquares.EDGE_LEFT)
	assert(left == Vector2(0, 0.5), "Left edge should be at middle of left")

func test_marching_squares_2x2_via_image():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a simple 2x2 pattern
	image.set_pixel(1, 1, Color(1, 1, 1, 1))
	image.set_pixel(2, 1, Color(1, 1, 1, 1))
	image.set_pixel(1, 2, Color(1, 1, 1, 1))
	image.set_pixel(2, 2, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Image with solid region should generate contours")
	assert(result[0].size() >= 3, "First contour should have at least 3 points")

func test_marching_squares_horizontal_line():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(5, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a horizontal line
	for x in range(1, 4):
		image.set_pixel(x, 1, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Horizontal line should generate contour")

func test_marching_squares_vertical_line():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(3, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a vertical line
	for y in range(1, 4):
		image.set_pixel(1, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Vertical line should generate contour")

func test_max_resolution_default():
	var algorithm = CutoutContourMarchingSquares.new()
	assert(algorithm.max_resolution == 0, "Default max_resolution should be 0 (no downscaling)")

func test_max_resolution_no_downscaling():
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.max_resolution = 512

	var image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(4, 6):
		for x in range(4, 6):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	for contour in result:
		for point in contour:
			assert(point.x <= 10 and point.y <= 10, "Points should be in original coordinate space")

func test_max_resolution_with_downscaling():
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.max_resolution = 50

	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(40, 60):
		for x in range(40, 60):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Downscaled image should still generate contours")

	var found_points_in_range := false
	for contour in result:
		for point in contour:
			if point.x >= 35 and point.x <= 65 and point.y >= 35 and point.y <= 65:
				found_points_in_range = true
			assert(point.x >= 0 and point.x <= 100, "X coordinate should be in original space")
			assert(point.y >= 0 and point.y <= 100, "Y coordinate should be in original space")

	assert(found_points_in_range, "Should find contour points near the square location")
