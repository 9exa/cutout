//! Polygon simplification algorithms for reducing vertex count
//!
//! This module provides implementations of:
//! - RDP (Ramer-Douglas-Peucker) - Distance-based simplification
//! - Visvalingam-Whyatt - Area-based simplification

pub mod rdp;
pub mod visvalingam_whyatt;

// Note: Traits are commented out for now - can be added when implementing
//
// use godot::prelude::*;
//
// /// Common trait for all polygon simplification algorithms
// pub trait SimplifyAlgorithm {
//     /// Simplify a polygon by reducing the number of vertices
//     ///
//     /// Returns a simplified version of the input polygon with fewer points
//     /// while maintaining the overall shape within tolerance.
//     fn simplify(&self, polygon: PackedVector2Array) -> PackedVector2Array;
// }
