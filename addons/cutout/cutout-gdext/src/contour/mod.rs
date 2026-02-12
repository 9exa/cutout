//! Contour detection algorithms for extracting polygon boundaries from images
//!
//! This module provides implementations of:
//! - Marching Squares (pixel-perfect contours with sub-pixel accuracy)
//! - Moore Neighbor (pixel-based boundary tracing)

pub mod grid;
pub mod marching_squares;
pub mod moore_neighbour;
pub mod processor;
pub mod settings;

// Re-export key types for convenient access
pub use grid::Grid;
pub use processor::ContourProcessor;
pub use settings::ContourSettings;

use crate::common::Grid2D;
use godot::{classes::Image, prelude::*};

/// Common trait for all contour detection algorithms
pub trait ContourAlgorithm {
    /// Calculate boundary contours from an image
    ///
    /// Returns an array of contours, where each contour is a PackedVector2Array
    /// of points forming a closed polygon.
    fn calculate_boundary(&self, image: Gd<Image>) -> Array<PackedVector2Array>;
}

// pub(super) fn alpha_to_grid(
//     image: GdRef<Image>,
//     alpha_threshold: f32,
//     resolution: Option<(f32, f32)>,
// ) -> Grid2D<bool> {
//     let reduced_image = resolution
//         .map(|(scale_x, scale_y)| {
//             let new_width = (image.get_width() as f32 * scale_x) as u32;
//             let new_height = (image.get_height() as f32 * scale_y) as u32;
//             let mut resized_image = Image::create(new_width, new_height, false, image.get_format());
//             resized_image.blit_rect(
//                 &image,
//                 Rect2::new(
//                     Vector2::ZERO,
//                     Vector2::new(image.get_width() as f32, image.height() as f32),
//                 ),
//                 Vector2::ZERO,
//             );
//             resized_image
//         })
//         .unwrap_or_else(|| image.into_shared());
//
//     let mut grid = Grid2D::new(image.width() as usize, image.height() as usize);
//     for x in 0..image.width() {
//         for y in 0..image.height() {
//             let color = image.get_pixel(x, y);
//             let alpha = color.a();
//             grid.set(x as usize, y as usize, alpha > alpha_threshold);
//         }
//     }
// }
