//! Common Data Structures and Utilities for the Cutout GD Extension

use godot::classes::Image;
use godot::prelude::*;

/// Just a simple 2D grid
#[derive(Debug, Clone, Default)]
pub struct Grid2D<T> {
    data: Vec<T>,
    width: usize,
    height: usize,
}

impl<T: Default + Clone> Grid2D<T> {
    pub fn new(width: usize, height: usize) -> Self {
        Self {
            data: vec![T::default(); width * height],
            width,
            height,
        }
    }
}

impl<T> Grid2D<T> {
    pub fn new_with_default(width: usize, height: usize, default_value: T) -> Self
    where
        T: Clone,
    {
        Self {
            data: vec![default_value; width * height],
            width,
            height,
        }
    }

    pub fn get_at(&self, x: usize, y: usize) -> Option<&T> {
        if x < self.width && y < self.height {
            Some(&self.data[y * self.width + x])
        } else {
            None
        }
    }

    pub fn set(&mut self, x: usize, y: usize, value: T) -> bool {
        if x < self.width && y < self.height {
            self.data[y * self.width + x] = value;
            true
        } else {
            false
        }
    }

    #[inline]
    pub fn width(&self) -> usize {
        self.width
    }

    #[inline]
    pub fn height(&self) -> usize {
        self.height
    }
}

/// Specialized implementation for bool grids (used for contour detection)
impl Grid2D<bool> {
    /// Create a binary grid from a Godot Image using an alpha threshold
    ///
    /// Pixels with alpha > threshold become true (solid), others false (empty)
    pub fn from_image(image: &Image, threshold: f32) -> Self {
        let width = image.get_width() as usize;
        let height = image.get_height() as usize;
        let mut data = Vec::with_capacity(width * height);

        // Ensure image is decompressed for pixel access
        let mut working_image = image.clone();
        working_image.decompress();

        // Convert pixels to binary based on alpha threshold
        for y in 0..height {
            for x in 0..width {
                let color = working_image.get_pixel(x as i32, y as i32);
                data.push(color.a > threshold);
            }
        }

        Self {
            data,
            width,
            height,
        }
    }

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
        let x = x as usize;
        let y = y as usize;
        if x >= self.width || y >= self.height {
            return None;
        }
        Some(&self.data[y * self.width + x])
    }
}
