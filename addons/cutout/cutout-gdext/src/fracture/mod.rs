//! Polygon fracturing/destruction algorithms
//!
//! This module provides implementations of:
//! - Voronoi fracturing - Break polygons into irregular pieces using Voronoi diagrams
//! - Slice fracturing - Cut polygons along lines

pub mod slice;
pub mod voronoi;

use godot::prelude::*;

/// Common trait for all destruction/fracturing algorithms
pub trait DestructionAlgorithm {
    /// Fracture polygons into multiple fragments
    ///
    /// Takes an array of polygons (first = outer boundary, rest = holes)
    /// Returns an array of fragment polygons.
    fn fracture(&self, polygons: Array<PackedVector2Array>) -> Array<PackedVector2Array>;
}
