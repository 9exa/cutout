extends Node

## Tests for CutoutContourMarchingSquares algorithm

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
	assert(result.size() > 0, "Single pixel should generate contour points")

func test_marching_squares_simple_square():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Fill with transparent

	# Create a 2x2 solid square in the middle
	for y in range(1, 3):
		for x in range(1, 3):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "2x2 square should generate contour points")
	# Marching squares should create points around the perimeter
	assert(result.size() % 2 == 0, "Result should have even number of points (line segments)")

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

func test_get_edge_pos_static():
	# Test the static _get_edge_point_fast helper function
	var top = CutoutContourMarchingSquares._get_edge_point_fast(0, 0, 0)
	assert(top == Vector2(0.5, 0), "Top edge should be at middle of top")

	var right = CutoutContourMarchingSquares._get_edge_point_fast(0, 0, 1)
	assert(right == Vector2(1.0, 0.5), "Right edge should be at middle of right")

	var bottom = CutoutContourMarchingSquares._get_edge_point_fast(0, 0, 2)
	assert(bottom == Vector2(0.5, 1.0), "Bottom edge should be at middle of bottom")

	var left = CutoutContourMarchingSquares._get_edge_point_fast(0, 0, 3)
	assert(left == Vector2(0, 0.5), "Left edge should be at middle of left")

func test_marching_squares_with_bitmap():
	# Test the static _marching_squares_all function directly with a BitMap
	var bitmap = BitMap.new()
	bitmap.create(Vector2i(4, 4))

	# Create a simple pattern
	bitmap.set_bit(1, 1, true)
	bitmap.set_bit(2, 1, true)
	bitmap.set_bit(1, 2, true)
	bitmap.set_bit(2, 2, true)

	var result = CutoutContourMarchingSquares._marching_squares_optimized(bitmap)
	assert(result.size() > 0, "Bitmap with solid region should generate contours")
	assert(result[0].size() > 0, "First contour should have points")
	assert(result.size() % 2 == 0, "Result should have even number of points")

func test_marching_squares_horizontal_line():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(5, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a horizontal line
	for x in range(1, 4):
		image.set_pixel(x, 1, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Horizontal line should generate contour points")

func test_marching_squares_vertical_line():
	var algorithm = CutoutContourMarchingSquares.new()
	var image = Image.create(3, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Create a vertical line
	for y in range(1, 4):
		image.set_pixel(1, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Vertical line should generate contour points")

func test_max_resolution_default():
	var algorithm = CutoutContourMarchingSquares.new()
	assert(algorithm.max_resolution == 0, "Default max_resolution should be 0 (no downscaling)")

func test_max_resolution_no_downscaling():
	# Image smaller than max_resolution should not be downscaled
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.max_resolution = 512

	var image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Create a 2x2 square
	for y in range(4, 6):
		for x in range(4, 6):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	# Points should be in original 10x10 coordinate space
	for contour in result:
		for point in contour:
			assert(point.x <= 10 and point.y <= 10, "Points should be in original coordinate space")

func test_max_resolution_with_downscaling():
	# Large image should be downscaled but coordinates scaled back
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.max_resolution = 50

	# Create 100x100 image with a square in the middle
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Create a square from (40,40) to (60,60)
	for y in range(40, 60):
		for x in range(40, 60):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Downscaled image should still generate contours")

	# Verify points are scaled back to original 100x100 space
	var found_points_in_range := false
	for contour in result:
		for point in contour:
			# Points should be near the 40-60 range in original coordinates
			if point.x >= 35 and point.x <= 65 and point.y >= 35 and point.y <= 65:
				found_points_in_range = true
			# All points should be within original image bounds
			assert(point.x >= 0 and point.x <= 100, "X coordinate should be in original space")
			assert(point.y >= 0 and point.y <= 100, "Y coordinate should be in original space")

	assert(found_points_in_range, "Should find contour points near the square location")

func test_max_resolution_aspect_ratio():
	# Test that aspect ratio is preserved during downscaling
	var algorithm = CutoutContourMarchingSquares.new()
	algorithm.max_resolution = 32

	# Create 128x64 image (2:1 aspect ratio)
	var image = Image.create(128, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Create a square in corner
	for y in range(2, 6):
		for x in range(2, 6):
			image.set_pixel(x, y, Color(1, 1, 1, 1))

	var result = algorithm.calculate_boundary(image)
	assert(result.size() > 0, "Non-square image should generate contours")

	# Points should still be in original 128x64 coordinate space
	for contour in result:
		for point in contour:
			assert(point.x >= 0 and point.x <= 128, "X should be in original width")
			assert(point.y >= 0 and point.y <= 64, "Y should be in original height")
