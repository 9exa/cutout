//! Grid alias and utilities for contour detection
//!
//! Grid is a type alias for Grid2D<bool>, providing a binary grid representation
//! for image data with efficient boundary checking and pixel access.

use godot::classes::image::Format;
use godot::classes::Image;
use godot::prelude::*;

use crate::common::Grid2D;

pub type Grid = Grid2D<bool>;

/// Bytes per pixel for RGBA8
const RGBA8_BPP: usize = 4;
/// Alpha channel offset within an RGBA8 pixel
const RGBA8_ALPHA_OFFSET: usize = 3;

/// Find the topmost, then leftmost solid pixel in the grid.
///
/// Scans from top to bottom, left to right, returning the first solid pixel found.
pub fn first_top_left_solid_pixel(grid: &Grid) -> Option<Vector2> {
    for y in 0..grid.height() {
        for x in 0..grid.width() {
            if let Some(&true) = grid.get_at(x, y) {
                return Some(Vector2::new(x as f32, y as f32));
            }
        }
    }
    None
}

/// Find the bottommost, then leftmost solid pixel in the grid.
///
/// Scans from bottom to top, left to right, returning the first solid pixel found.
pub fn first_bottom_left_solid_pixel(grid: &Grid) -> Option<Vector2> {
    for y in (0..grid.height()).rev() {
        for x in 0..grid.width() {
            if let Some(&true) = grid.get_at(x, y) {
                return Some(Vector2::new(x as f32, y as f32));
            }
        }
    }
    None
}

/// Create a binary grid from a Godot Image using an alpha threshold.
///
/// The image **must** already be decompressed and in RGBA8 format.
/// Call `Image::decompress()` and `Image::convert(Format::RGBA8)` before
/// passing the image to this function. The processor methods handle this.
///
/// Internally calls `Image::get_data()` once to bulk-read the pixel buffer,
/// then iterates entirely in Rust with no further FFI calls.
pub fn create_grid_from_image(image: &Image, threshold: f32) -> Grid {
    debug_assert_eq!(
        image.get_format(),
        Format::RGBA8,
        "create_grid_from_image: expected RGBA8, got {:?}",
        image.get_format(),
    );

    let width = image.get_width() as usize;
    let height = image.get_height() as usize;

    // Single FFI call - copies the entire pixel buffer into Rust
    let data = image.get_data();
    let threshold_byte = (threshold * 255.0) as u8;

    let grid_data: Vec<bool> = (0..width * height)
        .map(|i| data[i * RGBA8_BPP + RGBA8_ALPHA_OFFSET] > threshold_byte)
        .collect();

    Grid::from_raw(width, height, grid_data)
}

/// Specialized implementation for bool grids (used for contour detection)
impl Grid2D<bool> {
    /// Get a pixel value with signed coordinates
    ///
    /// Returns None for out-of-bounds or negative coordinates.
    /// This method is specifically for contour detection where neighbors
    /// may be checked at negative indices.
    #[inline]
    pub fn get(&self, x: i32, y: i32) -> Option<&bool> {
        if x < 0 || y < 0 {
            return None;
        }
        self.get_at(x as usize, y as usize)
    }
}
