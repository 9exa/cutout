//! Common Data Structures and Utilities for the Cutout GD Extension

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

    pub fn get(&self, x: usize, y: usize) -> Option<&T> {
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
}
