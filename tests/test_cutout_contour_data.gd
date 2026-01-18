extends Node

## Tests for CutoutContourData resource

func test_contour_data_initialization():
	var contour_data = CutoutContourData.new()
	assert(contour_data != null, "CutoutContourData should be created")
	assert(contour_data.points.size() == 0, "Points array should be empty initially")

func test_contour_data_points_storage():
	var contour_data = CutoutContourData.new()
	var test_points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 1),
		Vector2(2, 2)
	])

	contour_data.points.append(test_points)
	assert(contour_data.points.size() == 1, "Should have one contour")
	assert(contour_data.points[0].size() == 3, "First contour should have 3 points")
	assert(contour_data.points[0][0] == Vector2(0, 0), "First point should match")

func test_contour_data_clear():
	var contour_data = CutoutContourData.new()
	var test_points = PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])

	contour_data.points.append(test_points)
	assert(contour_data.points.size() == 1, "Should have one contour before clear")

	contour_data.clear()
	assert(contour_data.points.size() == 0, "Points should be empty after clear")

func test_contour_data_multiple_contours():
	var contour_data = CutoutContourData.new()
	var contour1 = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	var contour2 = PackedVector2Array([Vector2(5, 5), Vector2(6, 6)])

	contour_data.points.append(contour1)
	contour_data.points.append(contour2)

	assert(contour_data.points.size() == 2, "Should have two contours")
	assert(contour_data.points[0][0] == Vector2(0, 0), "First contour first point")
	assert(contour_data.points[1][0] == Vector2(5, 5), "Second contour first point")
