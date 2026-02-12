//! Grid data structure for efficient contour detection
//!
//! This module provides a binary grid representation optimized for:
//! - Cache-efficient contiguous storage (Vec<bool>)
//! - Fast pixel lookups during contour tracing
//! - Conversion from Godot Image with alpha threshold

use godot::prelude::*;
use godot::classes::Image;

/// Binary grid representing solid/empty pixels
#[derive(Debug, Clone)]
pub struct Grid {
    data: Vec<bool>,
    width: usize,
    height: usize,
}

impl Grid {
    /// Create a Grid from a Godot Image using an alpha threshold
    ///
    /// # Arguments
    /// * `image` - The source image
    /// * `threshold` - Alpha threshold (0.0-1.0) for determining solid pixels
    ///
    /// # Returns
    /// A Grid where true = solid pixel (alpha > threshold)
    pub fn from_image(image: &Gd<Image>, threshold: f32) -> Self {
        // Handle compressed images by decompressing if needed
        let mut working_image = image.clone();
        if working_image.is_compressed() {
            working_image.decompress();
        }

        let width = working_image.get_width() as usize;
        let height = working_image.get_height() as usize;
        let mut data = Vec::with_capacity(width * height);

        // Convert pixels to bool based on alpha threshold
        for y in 0..height {
            for x in 0..width {
                let color = working_image.get_pixel(x as i32, y as i32);
                let is_solid = color.a > threshold;
                data.push(is_solid);
            }
        }

        Self {
            data,
            width,
            height,
        }
    }

    /// Get a pixel value with bounds checking
    ///
    /// # Arguments
    /// * `x` - X coordinate (can be negative or out of bounds)
    /// * `y` - Y coordinate (can be negative or out of bounds)
    ///
    /// # Returns
    /// true if the pixel is solid and in bounds, false otherwise
    #[inline]
    pub fn get(&self, x: i32, y: i32) -> bool {
        if x < 0 || y < 0 {
            return false;
        }
        let ux = x as usize;
        let uy = y as usize;
        if ux >= self.width || uy >= self.height {
            return false;
        }
        self.data[uy * self.width + ux]
    }

    /// Get the width of the grid
    #[inline]
    pub fn width(&self) -> usize {
        self.width
    }

    /// Get the height of the grid
    #[inline]
    pub fn height(&self) -> usize {
        self.height
    }
}
