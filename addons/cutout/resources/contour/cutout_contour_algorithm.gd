@tool
@abstract
class_name CutoutContourAlgorithm
extends Resource
## Algorithms for producing CutoutContourData fromtextures.


## The transparency level (0.0 to 1.0) to consider a pixel "solid"
@export_range(0.0, 1.0) var alpha_threshold: float = 0.5:
	set(value):
		alpha_threshold = value
		emit_changed()

## Maximum resolution for contour generation (0 = no downscaling)
## High-res images will be downscaled to fit within this dimension for processing,
## then contour points are scaled back to original coordinates for accuracy.
## Improves performance significantly for large images (e.g., 2048x2048 → 512x512).
@export_range(0, 4096, 1, "or_greater") var max_resolution: int = 0:
	set(value):
		max_resolution = value
		emit_changed()

## Produce the boundary points from a given image.
func calculate_boundary(image: Image) -> Array[PackedVector2Array]:
	if image == null:
		return []

	# Store original size for coordinate scaling
	var original_size := Vector2i(image.get_width(), image.get_height())

	# Determine if downscaling is needed
	var max_dim: int = max(original_size.x, original_size.y)
	var needs_downscale: bool = max_resolution > 0 and max_dim > max_resolution

	var processing_image: Image
	var scale_factor := Vector2.ONE

	if needs_downscale:
		# Calculate new size maintaining aspect ratio
		var scale := float(max_resolution) / float(max_dim)
		var new_size := Vector2i(
			max(1, int(original_size.x * scale)),
			max(1, int(original_size.y * scale))
		)

		# Downscale the image
		processing_image = image.duplicate()
		processing_image.resize(new_size.x, new_size.y, Image.INTERPOLATE_BILINEAR)

		# Calculate scale factor for point conversion
		scale_factor = Vector2(
			float(original_size.x) / float(new_size.x),
			float(original_size.y) / float(new_size.y)
		)
	else:
		# Use original image
		processing_image = image

	# Generate contours
	var contours := _calculate_boundary(processing_image)

	# Scale contour points back to original coordinates if needed
	if needs_downscale:
		for contour in contours:
			for i in range(contour.size()):
				contour[i] = contour[i] * scale_factor

	return contours
	


## Virtual. Concrete implementation of calculate_boundary
@abstract func _calculate_boundary(_image: Image) -> Array[PackedVector2Array]
