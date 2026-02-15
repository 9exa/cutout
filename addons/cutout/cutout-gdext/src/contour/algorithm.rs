use godot::classes::Image;
use godot::prelude::*;

/// Calculate boundary contours from an image
pub trait ContourAlgorithm {
    /// # Arguments
    /// * `image` - Input image to process
    /// * `alpha_threshold` - Threshold for determining solid pixels (0.0 - 1.0)
    /// * `max_resolution` - Maximum resolution for downscaling (NO_RESOLUTION_LIMIT = no limit)
    ///
    /// # Returns
    /// Vector of contours, each contour is a vector of points
    fn calculate_boundary(
        image: &Image,
        alpha_threshold: f32,
        max_resolution: Vector2,
    ) -> Vec<Vec<Vector2>>;
}
