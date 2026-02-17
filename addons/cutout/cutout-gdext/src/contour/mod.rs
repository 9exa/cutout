//! Contour detection algorithms for extracting polygon boundaries from images
//!
//! This module provides implementations of:
//! - Marching Squares (pixel-perfect contours with sub-pixel accuracy)
//! - Moore Neighbor (pixel-based boundary tracing)

pub mod algorithm;
pub mod grid;
pub mod marching_squares;
pub mod moore_neighbour;
pub mod processor;
pub mod settings;

// Re-export key types for convenient access
pub use grid::Grid;
pub use processor::CutoutContourProcessor;
pub use settings::ContourSettings;
