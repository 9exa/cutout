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

    /// Fracture polygons using radial slice pattern.
    ///
    /// Creates slices radiating from a central origin point.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed` - Random seed for angle variation
    /// * `slice_count` - Number of radial slices
    /// * `origin` - Center point for radial slices (Vector2.ZERO = polygon center)
    /// * `radial_randomness` - Random angle variation (0-1)
    #[func]
    pub fn fracture_slices_radial(
        polygons: Array<PackedVector2Array>,
        seed: i64,
        slice_count: i32,
        origin: Vector2,
        radial_randomness: f32,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_radial(
            &polygons,
            seed,
            slice_count,
            origin,
            radial_randomness,
        )
    }

    /// Fracture polygons using parallel slice pattern.
    ///
    /// Creates parallel slices at a specified angle.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed` - Random seed for angle variation
    /// * `slice_count` - Number of parallel slices
    /// * `parallel_angle` - Base angle in degrees
    /// * `parallel_angle_rand` - Random angle variation (0-1)
    #[func]
    pub fn fracture_slices_parallel(
        polygons: Array<PackedVector2Array>,
        seed: i64,
        slice_count: i32,
        parallel_angle: f32,
        parallel_angle_rand: f32,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_parallel(
            &polygons,
            seed,
            slice_count,
            parallel_angle,
            parallel_angle_rand,
        )
    }

    /// Fracture polygons using grid slice pattern.
    ///
    /// Creates a grid of horizontal and vertical slices.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed` - Random seed for position/angle variation
    /// * `grid_h_start` - Starting X position for vertical lines
    /// * `grid_v_start` - Starting Y position for horizontal lines
    /// * `grid_h_slices` - Number of vertical slices
    /// * `grid_v_slices` - Number of horizontal slices
    /// * `grid_h_random` - Position randomness for vertical lines (0-1)
    /// * `grid_v_random` - Position randomness for horizontal lines (0-1)
    /// * `grid_h_angle_rand` - Angle randomness for vertical lines (0-1)
    /// * `grid_v_angle_rand` - Angle randomness for horizontal lines (0-1)
    #[func]
    pub fn fracture_slices_grid(
        polygons: Array<PackedVector2Array>,
        seed: i64,
        grid_h_start: f32,
        grid_v_start: f32,
        grid_h_slices: i32,
        grid_v_slices: i32,
        grid_h_random: f32,
        grid_v_random: f32,
        grid_h_angle_rand: f32,
        grid_v_angle_rand: f32,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_grid(
            &polygons,
            seed,
            grid_h_start,
            grid_v_start,
            grid_h_slices,
            grid_v_slices,
            grid_h_random,
            grid_v_random,
            grid_h_angle_rand,
            grid_v_angle_rand,
        )
    }

    /// Fracture polygons using chaotic slice pattern.
    ///
    /// Creates random slices across the polygon.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed` - Random seed for slice generation
    /// * `slice_count` - Number of random slices
    #[func]
    pub fn fracture_slices_chaotic(
        polygons: Array<PackedVector2Array>,
        seed: i64,
        slice_count: i32,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_chaotic(
            &polygons,
            seed,
            slice_count,
        )
    }

    /// Fracture polygons using manually-provided slice segments.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `segments` - Slice lines; each element is a 2-point PackedVector2Array [a, b]
    ///
    /// # Returns
    /// Array of polygon fragments
    #[func]
    pub fn fracture_slices_manual(
        polygons: Array<PackedVector2Array>,
        segments: Array<PackedVector2Array>,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_manual(&polygons, &segments)
    }

    /// Optimized parallel slice fracture with projection-bound culling.
    ///
    /// Generates parallel segments internally and applies them with spatial
    /// optimization that skips polygons not intersecting the current cut.
    ///
    /// # Arguments
    /// * `polygons` - Array of polygons (first = outer boundary, rest = holes)
    /// * `seed` - Random seed for angle variation
    /// * `slice_count` - Number of parallel slices
    /// * `parallel_angle` - Base angle in degrees
    /// * `parallel_angle_rand` - Random angle variation (0-1)
    #[func]
    pub fn fracture_slices_parallel_optimized(
        polygons: Array<PackedVector2Array>,
        seed: i64,
        slice_count: i32,
        parallel_angle: f32,
        parallel_angle_rand: f32,
    ) -> Array<PackedVector2Array> {
        slice::fracture_slices_parallel_optimized(
            &polygons,
            seed,
            slice_count,
            parallel_angle,
            parallel_angle_rand,
        )
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
