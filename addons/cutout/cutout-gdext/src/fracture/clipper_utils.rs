//! Shared Clipper2 utility functions for polygon operations
//!
//! These utilities convert between Godot's Vector2 format and Clipper2's format,
//! and provide common polygon clipping operations.

use clipper2::{difference, intersect, FillRule, Paths};
use godot::prelude::*;

/// Convert a Godot polygon to Clipper2 format
pub fn to_clipper_path(polygon: &[Vector2]) -> Vec<(f64, f64)> {
    polygon.iter().map(|p| (p.x as f64, p.y as f64)).collect()
}

/// Convert Clipper2 paths back to Godot format
pub fn from_clipper_paths(paths: Paths) -> Vec<Vec<Vector2>> {
    paths
        .iter()
        .map(|path| {
            path.iter()
                .map(|p| Vector2::new(p.x() as f32, p.y() as f32))
                .collect()
        })
        .collect()
}

/// Compute the intersection of two polygons using Clipper2
pub fn clipper2_intersect(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match intersect(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(e) => {
            godot_error!("Clipper2 intersect operation failed: {:?}", e);
            Vec::new()  // Return empty on error (no intersection)
        }
    }
}

/// Compute the difference of two polygons using Clipper2 (subject - clip)
pub fn clipper2_difference(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match difference(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(e) => {
            godot_error!("Clipper2 difference operation failed: {:?}", e);
            vec![subject.to_vec()]  // On error, return original polygon unchanged
        }
    }
}