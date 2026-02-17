//! CutoutDestructionProcessor - Batch processing API for polygon fracture/destruction
//!
//! This module provides high-level APIs for fracturing polygons using various
//! algorithms and seed patterns. Follows the same stateless Processor pattern
//! as CutoutContourProcessor.

use super::seeds;
use super::voronoi;
use super::slice;
use godot::prelude::*;

/// Main processor for polygon fracture/destruction operations.
///
/// This is a stateless utility class providing static methods for polygon fracturing.
/// All methods can be called directly without instantiation.
#[derive(GodotClass)]
#[class(no_init)]
pub struct CutoutDestructionProcessor;

#[godot_api]
impl CutoutDestructionProcessor {
    // ========================================================================
    // Fracture Methods
    // ========================================================================

    /// Fracture polygons using Voronoi diagram from pre-computed seed points.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed_points` - Pre-generated seed points for Voronoi cell centers
    ///
    /// # Returns
    /// Array of polygon fragments
    #[func]
    pub fn fracture_voronoi(
        polygons: Array<PackedVector2Array>,
        seed_points: PackedVector2Array,
    ) -> Array<PackedVector2Array> {
        voronoi::fracture(&polygons, &seed_points)
    }

    /// Fracture polygons along a line segment.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `line_start` - Start point of the slice line
    /// * `line_end` - End point of the slice line
    ///
    /// # Returns
    /// Array of polygon fragments (typically 2, or original if line misses)
    #[func]
    pub fn fracture_slice(
        polygons: Array<PackedVector2Array>,
        line_start: Vector2,
        line_end: Vector2,
    ) -> Array<PackedVector2Array> {
        slice::fracture(&polygons, line_start, line_end)
    }

    // ========================================================================
    // Seed Generation Methods
    // ========================================================================

    /// Generate random seed points within a polygon.
    ///
    /// Pure random distribution - creates natural shattering patterns.
    #[func]
    pub fn generate_random_seeds(
        polygon: PackedVector2Array,
        fragment_count: i32,
        min_cell_distance: f32,
        edge_padding: f32,
        seed: i64,
    ) -> PackedVector2Array {
        let poly: Vec<Vector2> = polygon.to_vec();
        let result = seeds::generate_random(&poly, fragment_count, min_cell_distance, edge_padding, seed);
        PackedVector2Array::from(result.as_slice())
    }

    /// Generate grid-based seed points with jitter.
    ///
    /// Creates organized destruction patterns (tiles, bricks).
    #[func]
    pub fn generate_grid_seeds(
        polygon: PackedVector2Array,
        rows: i32,
        cols: i32,
        jitter: f32,
        min_cell_distance: f32,
        edge_padding: f32,
        seed: i64,
    ) -> PackedVector2Array {
        let poly: Vec<Vector2> = polygon.to_vec();
        let result = seeds::generate_grid(&poly, rows, cols, jitter, min_cell_distance, edge_padding, seed);
        PackedVector2Array::from(result.as_slice())
    }

    /// Generate radial seed points in concentric rings.
    ///
    /// Creates impact/explosion patterns.
    #[func]
    pub fn generate_radial_seeds(
        polygon: PackedVector2Array,
        origin: Vector2,
        ring_count: i32,
        ring_size: f32,
        points_per_ring: i32,
        radial_variation: f32,
        min_cell_distance: f32,
        seed: i64,
    ) -> PackedVector2Array {
        let poly: Vec<Vector2> = polygon.to_vec();
        let result = seeds::generate_radial(
            &poly, origin, ring_count, ring_size, points_per_ring,
            radial_variation, min_cell_distance, seed,
        );
        PackedVector2Array::from(result.as_slice())
    }

    /// Generate spiderweb seed points (radial rays + concentric rings).
    ///
    /// Creates cracked glass patterns.
    #[func]
    pub fn generate_spiderweb_seeds(
        polygon: PackedVector2Array,
        origin: Vector2,
        ring_count: i32,
        ring_size: f32,
        points_per_ring: i32,
        radial_variation: f32,
        min_cell_distance: f32,
        seed: i64,
    ) -> PackedVector2Array {
        let poly: Vec<Vector2> = polygon.to_vec();
        let result = seeds::generate_spiderweb(
            &poly, origin, ring_count, ring_size, points_per_ring,
            radial_variation, min_cell_distance, seed,
        );
        PackedVector2Array::from(result.as_slice())
    }

    /// Generate Poisson disk distributed seed points (blue noise).
    ///
    /// Creates high-quality natural fracture patterns with even spacing.
    #[func]
    pub fn generate_poisson_seeds(
        polygon: PackedVector2Array,
        fragment_count: i32,
        min_cell_distance: f32,
        edge_padding: f32,
        poisson_attempts: i32,
        seed: i64,
    ) -> PackedVector2Array {
        let poly: Vec<Vector2> = polygon.to_vec();
        let result = seeds::generate_poisson(
            &poly, fragment_count, min_cell_distance, edge_padding,
            poisson_attempts, seed,
        );
        PackedVector2Array::from(result.as_slice())
    }
}
