//! Seed point generation for Voronoi fracturing
//!
//! Provides 5 seed distribution patterns:
//! - Random: Pure random distribution for natural shattering
//! - Grid: Grid-based with jitter for organized destruction
//! - Radial: Concentric rings for impact/explosion patterns
//! - Spiderweb: Radial rays + rings for cracked glass
//! - Poisson Disk: Blue noise for high-quality natural fractures
//!
//! Reference GDScript: addons/cutout/resources/destruction/cutout_destruction_voronoi.gd

use super::geometry::{calculate_bounds, grow_rect, is_far_enough, point_in_polygon};
use godot::prelude::*;

/// Simple deterministic RNG (xorshift64) for seed generation.
///
/// Avoids depending on external crate just for RNG - we only need uniform f64/f32.
struct Rng {
    state: u64,
}

impl Rng {
    fn new(seed: i64) -> Self {
        // Ensure non-zero state
        let state = if seed == 0 { 0xDEAD_BEEF_CAFE_BABE } else { seed as u64 };
        Self { state }
    }

    fn next_u64(&mut self) -> u64 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        self.state
    }

    /// Returns a float in [0, 1)
    fn randf(&mut self) -> f32 {
        (self.next_u64() >> 40) as f32 / (1u64 << 24) as f32
    }

    /// Returns a float in [min, max)
    fn randf_range(&mut self, min: f32, max: f32) -> f32 {
        min + self.randf() * (max - min)
    }

    /// Returns an integer in [0, max)
    fn randi_range(&mut self, max: usize) -> usize {
        (self.next_u64() as usize) % max
    }
}

/// Generate purely random seed points within a polygon.
pub fn generate_random(
    polygon: &[Vector2],
    fragment_count: i32,
    min_cell_distance: f32,
    edge_padding: f32,
    seed: i64,
) -> Vec<Vector2> {
    let mut rng = Rng::new(seed);
    let bounds = calculate_bounds(polygon);
    let padded = grow_rect(bounds, -edge_padding);

    if padded.size.x <= 0.0 || padded.size.y <= 0.0 {
        return Vec::new();
    }

    let min_dist = padded.size.x.min(padded.size.y) * min_cell_distance;
    let max_attempts = fragment_count as usize * 10;
    let mut points = Vec::new();

    for _ in 0..max_attempts {
        if points.len() >= fragment_count as usize {
            break;
        }

        let candidate = Vector2::new(
            rng.randf_range(padded.position.x, padded.position.x + padded.size.x),
            rng.randf_range(padded.position.y, padded.position.y + padded.size.y),
        );

        if point_in_polygon(candidate, polygon) && is_far_enough(candidate, &points, min_dist) {
            points.push(candidate);
        }
    }

    points
}

/// Generate grid-based seed points with optional jitter.
pub fn generate_grid(
    polygon: &[Vector2],
    rows: i32,
    cols: i32,
    jitter: f32,
    min_cell_distance: f32,
    edge_padding: f32,
    seed: i64,
) -> Vec<Vector2> {
    let mut rng = Rng::new(seed);
    let bounds = calculate_bounds(polygon);
    let padded = grow_rect(bounds, -edge_padding);

    if padded.size.x <= 0.0 || padded.size.y <= 0.0 {
        return Vec::new();
    }

    let min_dist = padded.size.x.min(padded.size.y) * min_cell_distance;
    let cell_size = Vector2::new(padded.size.x / cols as f32, padded.size.y / rows as f32);
    let mut points = Vec::new();

    for y in 0..rows {
        for x in 0..cols {
            let jitter_offset = Vector2::new(
                rng.randf_range(-0.5, 0.5) * cell_size.x * jitter,
                rng.randf_range(-0.5, 0.5) * cell_size.y * jitter,
            );

            let candidate = Vector2::new(
                padded.position.x + (x as f32 + 0.5) * cell_size.x + jitter_offset.x,
                padded.position.y + (y as f32 + 0.5) * cell_size.y + jitter_offset.y,
            );

            if point_in_polygon(candidate, polygon) && is_far_enough(candidate, &points, min_dist)
            {
                points.push(candidate);
            }
        }
    }

    points
}

/// Generate radial seed points in concentric rings.
pub fn generate_radial(
    polygon: &[Vector2],
    origin: Vector2,
    ring_count: i32,
    ring_size: f32,
    points_per_ring: i32,
    radial_variation: f32,
    min_cell_distance: f32,
    seed: i64,
) -> Vec<Vector2> {
    let mut rng = Rng::new(seed);
    let bounds = calculate_bounds(polygon);
    let center = if origin == Vector2::ZERO {
        bounds.position + bounds.size * 0.5
    } else {
        origin
    };

    let min_dist = bounds.size.x.min(bounds.size.y) * min_cell_distance;

    // Calculate max radius (distance to furthest corner)
    let corners = [
        bounds.position,
        Vector2::new(bounds.position.x + bounds.size.x, bounds.position.y),
        bounds.position + bounds.size,
        Vector2::new(bounds.position.x, bounds.position.y + bounds.size.y),
    ];
    let max_radius = corners
        .iter()
        .map(|c| (*c - center).length())
        .fold(0.0f32, f32::max);

    let mut points = Vec::new();

    for ring_idx in 0..ring_count {
        let ring_number = (ring_idx + 1) as f32;
        let base_radius = ring_number * ring_size;

        // More seeds in outer rings
        let seeds_in_ring =
            ((points_per_ring as f32 * ring_number / ring_count as f32).round() as i32).max(3);

        for i in 0..seeds_in_ring {
            let angle = std::f32::consts::TAU * i as f32 / seeds_in_ring as f32;

            let radius_var =
                rng.randf_range(-radial_variation, radial_variation) * (max_radius / ring_count as f32);
            let angle_var = rng.randf_range(-radial_variation, radial_variation)
                * (std::f32::consts::TAU / seeds_in_ring as f32);

            let radius = base_radius + radius_var;
            let final_angle = angle + angle_var;

            let candidate =
                center + Vector2::new(final_angle.cos(), final_angle.sin()) * radius;

            if point_in_polygon(candidate, polygon)
                && is_far_enough(candidate, &points, min_dist)
            {
                points.push(candidate);
            }
        }
    }

    points
}

/// Generate spiderweb seed points (radial rays + concentric rings).
pub fn generate_spiderweb(
    polygon: &[Vector2],
    origin: Vector2,
    ring_count: i32,
    ring_size: f32,
    points_per_ring: i32,
    radial_variation: f32,
    min_cell_distance: f32,
    seed: i64,
) -> Vec<Vector2> {
    let mut rng = Rng::new(seed);
    let bounds = calculate_bounds(polygon);
    let center = if origin == Vector2::ZERO {
        bounds.position + bounds.size * 0.5
    } else {
        origin
    };

    let min_dist = bounds.size.x.min(bounds.size.y) * min_cell_distance;

    // Calculate max radius
    let corners = [
        bounds.position,
        Vector2::new(bounds.position.x + bounds.size.x, bounds.position.y),
        bounds.position + bounds.size,
        Vector2::new(bounds.position.x, bounds.position.y + bounds.size.y),
    ];
    let max_radius = corners
        .iter()
        .map(|c| (*c - center).length())
        .fold(0.0f32, f32::max);

    let mut points = Vec::new();

    // Add center point
    if point_in_polygon(center, polygon) {
        points.push(center);
    }

    // Generate spokes with seeds at each ring intersection
    let ray_count = points_per_ring;

    for ray_idx in 0..ray_count {
        let base_angle = std::f32::consts::TAU * ray_idx as f32 / ray_count as f32;

        for ring_idx in 1..=ring_count {
            let radius = ring_idx as f32 * ring_size;

            let angle_var = rng.randf_range(-radial_variation, radial_variation)
                * (std::f32::consts::TAU / ray_count as f32 / 2.0);
            let radius_var = rng.randf_range(-radial_variation, radial_variation)
                * (max_radius / ring_count as f32 / 2.0);

            let final_angle = base_angle + angle_var;
            let final_radius = radius + radius_var;

            let candidate =
                center + Vector2::new(final_angle.cos(), final_angle.sin()) * final_radius;

            if point_in_polygon(candidate, polygon)
                && is_far_enough(candidate, &points, min_dist)
            {
                points.push(candidate);
            }
        }
    }

    points
}

/// Generate Poisson disk distributed seed points (blue noise).
pub fn generate_poisson(
    polygon: &[Vector2],
    fragment_count: i32,
    min_cell_distance: f32,
    edge_padding: f32,
    poisson_attempts: i32,
    seed: i64,
) -> Vec<Vector2> {
    let mut rng = Rng::new(seed);
    let bounds = calculate_bounds(polygon);
    let padded = grow_rect(bounds, -edge_padding);

    if padded.size.x <= 0.0 || padded.size.y <= 0.0 {
        return Vec::new();
    }

    let min_dist = padded.size.x.min(padded.size.y) * min_cell_distance;
    let max_total_attempts = fragment_count as usize * poisson_attempts as usize;

    let mut points = Vec::new();
    let mut active_list: Vec<Vector2> = Vec::new();

    // Start with random first point
    let first = Vector2::new(
        rng.randf_range(padded.position.x, padded.position.x + padded.size.x),
        rng.randf_range(padded.position.y, padded.position.y + padded.size.y),
    );

    if point_in_polygon(first, polygon) {
        points.push(first);
        active_list.push(first);
    }

    let mut total_attempts = 0;

    while !active_list.is_empty()
        && (points.len() as i32) < fragment_count
        && total_attempts < max_total_attempts
    {
        // Pick random point from active list
        let idx = rng.randi_range(active_list.len());
        let point = active_list[idx];

        let mut found_valid = false;

        for _ in 0..poisson_attempts {
            total_attempts += 1;

            // Generate point in annulus around current point
            let angle = rng.randf() * std::f32::consts::TAU;
            let radius = min_dist * (1.0 + rng.randf());

            let candidate =
                point + Vector2::new(angle.cos(), angle.sin()) * radius;

            // Check bounds
            let in_bounds = candidate.x >= padded.position.x
                && candidate.x <= padded.position.x + padded.size.x
                && candidate.y >= padded.position.y
                && candidate.y <= padded.position.y + padded.size.y;

            if !in_bounds {
                continue;
            }

            if !point_in_polygon(candidate, polygon) {
                continue;
            }

            if is_far_enough(candidate, &points, min_dist) {
                points.push(candidate);
                active_list.push(candidate);
                found_valid = true;
                break;
            }
        }

        if !found_valid {
            active_list.swap_remove(idx);
        }
    }

    points
}
