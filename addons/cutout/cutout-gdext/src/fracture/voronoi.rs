//! Voronoi-based polygon fracturing algorithm
//!
//! Reference GDScript: addons/cutout/resources/destruction/cutout_destruction_voronoi.gd
//!
//! This algorithm works by:
//! 1. Computing Delaunay triangulation of the seed points (via `delaunator`)
//! 2. Building adjacency from the triangulation
//! 3. Computing Voronoi cells by clipping a bounding box against perpendicular bisectors
//!    of each seed's Delaunay neighbors
//! 4. Clipping cells to the outer polygon (via `clipper2` intersect)
//! 5. Subtracting holes from fragments (via `clipper2` difference)

use super::geometry::{calculate_bounds, clip_polygon_to_half_plane};
use clipper2::*;
use godot::prelude::*;

/// Fracture polygons into Voronoi-based fragments.
///
/// # Arguments
/// * `polygons` - First = outer boundary, rest = holes
/// * `seed_points` - Voronoi cell centers (from any seed generator)
///
/// # Returns
/// Array of polygon fragments
pub fn fracture(
    polygons: &Array<PackedVector2Array>,
    seed_points: &PackedVector2Array,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() || seed_points.len() < 2 {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let seeds: Vec<Vector2> = seed_points.to_vec();
    let bounds = calculate_bounds(&outer);

    // Step 1: Delaunay triangulation
    let triangulation = delaunay(&seeds);
    let Some(triangulation) = triangulation else {
        godot_warn!("Voronoi fracture: Delaunay triangulation failed");
        return polygons.clone();
    };

    // Step 2: Build adjacency from triangulation
    let adjacency = build_adjacency(seeds.len(), &triangulation);

    // Step 3: Compute Voronoi cells
    let voronoi_cells = compute_voronoi_cells(&seeds, &adjacency, bounds);

    // Step 4 & 5: Clip cells to outer polygon and subtract holes
    let mut fragments = Array::new();

    // Collect holes
    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    // Precompute hole bounds for spatial culling
    let hole_bounds: Vec<Rect2> = holes.iter().map(|h| calculate_bounds(h)).collect();

    for cell in &voronoi_cells {
        if cell.len() < 3 {
            continue;
        }

        // Clip cell against outer polygon using clipper2
        let clipped = clipper2_intersect(cell, &outer);

        for fragment in clipped {
            if fragment.len() < 3 {
                continue;
            }

            // Subtract holes from fragment
            let remaining = subtract_holes(&fragment, &holes, &hole_bounds);

            for piece in remaining {
                if piece.len() >= 3 {
                    let mut packed = PackedVector2Array::new();
                    for p in &piece {
                        packed.push(*p);
                    }
                    fragments.push(&packed);
                }
            }
        }
    }

    if fragments.is_empty() {
        godot_warn!("Voronoi fracture: No valid fragments generated, returning original");
        return polygons.clone();
    }

    fragments
}

/// Compute Delaunay triangulation using the `delaunator` crate.
///
/// Returns triangle indices as a flat Vec (every 3 = one triangle), or None on failure.
fn delaunay(points: &[Vector2]) -> Option<Vec<usize>> {
    let coords: Vec<delaunator::Point> = points
        .iter()
        .map(|p| delaunator::Point {
            x: p.x as f64,
            y: p.y as f64,
        })
        .collect();

    let result = delaunator::triangulate(&coords);
    if result.triangles.is_empty() {
        return None;
    }

    Some(result.triangles)
}

/// Build an adjacency list from Delaunay triangulation.
///
/// Returns a Vec where adjacency[i] contains all neighbor indices of point i.
fn build_adjacency(num_points: usize, triangles: &[usize]) -> Vec<Vec<usize>> {
    let mut adjacency: Vec<Vec<usize>> = vec![Vec::new(); num_points];

    for tri in triangles.chunks_exact(3) {
        let (a, b, c) = (tri[0], tri[1], tri[2]);

        // Add bidirectional edges (avoid duplicates)
        if !adjacency[a].contains(&b) {
            adjacency[a].push(b);
        }
        if !adjacency[b].contains(&a) {
            adjacency[b].push(a);
        }
        if !adjacency[b].contains(&c) {
            adjacency[b].push(c);
        }
        if !adjacency[c].contains(&b) {
            adjacency[c].push(b);
        }
        if !adjacency[c].contains(&a) {
            adjacency[c].push(a);
        }
        if !adjacency[a].contains(&c) {
            adjacency[a].push(c);
        }
    }

    adjacency
}

/// Compute Voronoi cells by half-plane clipping against Delaunay neighbors.
///
/// Each cell starts as the bounding box and is clipped against perpendicular
/// bisectors of each neighbor.
fn compute_voronoi_cells(
    seeds: &[Vector2],
    adjacency: &[Vec<usize>],
    bounds: Rect2,
) -> Vec<Vec<Vector2>> {
    let mut cells = Vec::with_capacity(seeds.len());

    for (i, center) in seeds.iter().enumerate() {
        // Start with bounding box
        let mut cell = vec![
            bounds.position,
            Vector2::new(bounds.position.x + bounds.size.x, bounds.position.y),
            bounds.position + bounds.size,
            Vector2::new(bounds.position.x, bounds.position.y + bounds.size.y),
        ];

        // Clip against each neighbor's perpendicular bisector
        for &neighbor_idx in &adjacency[i] {
            let other = seeds[neighbor_idx];
            let midpoint = (*center + other) * 0.5;
            // Normal points from neighbor toward center (keeps center's side)
            let normal = (*center - other).normalized();

            cell = clip_polygon_to_half_plane(&cell, midpoint, normal);

            if cell.len() < 3 {
                break;
            }
        }

        if cell.len() >= 3 {
            cells.push(cell);
        }
    }

    cells
}

// ============================================================================
// Clipper2 integration
// ============================================================================

/// Convert Vec<Vector2> (f32) to a clipper2-compatible path of (f64, f64) tuples.
fn to_clipper_path(polygon: &[Vector2]) -> Vec<(f64, f64)> {
    polygon.iter().map(|p| (p.x as f64, p.y as f64)).collect()
}

/// Convert clipper2 result Paths back to Vec<Vec<Vector2>>.
fn from_clipper_paths(paths: Paths) -> Vec<Vec<Vector2>> {
    paths
        .iter()
        .map(|path| {
            path.iter()
                .map(|p| Vector2::new(p.x() as f32, p.y() as f32))
                .collect()
        })
        .collect()
}

/// Intersect two polygons using clipper2.
fn clipper2_intersect(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match intersect(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(_) => Vec::new(),
    }
}

/// Subtract a polygon (hole) from a subject polygon using clipper2.
fn clipper2_difference(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match difference(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(_) => vec![subject.to_vec()], // On error, return original
    }
}

/// Subtract all holes from a fragment, with spatial culling.
fn subtract_holes(
    fragment: &[Vector2],
    holes: &[Vec<Vector2>],
    hole_bounds: &[Rect2],
) -> Vec<Vec<Vector2>> {
    let mut remaining = vec![fragment.to_vec()];

    if holes.is_empty() {
        return remaining;
    }

    let fragment_bounds = calculate_bounds(fragment);

    for (hole_idx, hole) in holes.iter().enumerate() {
        // Spatial culling: skip holes that don't overlap fragment bounds
        if !rects_intersect(fragment_bounds, hole_bounds[hole_idx]) {
            continue;
        }

        let mut next_remaining = Vec::new();

        for piece in &remaining {
            let after_subtract = clipper2_difference(piece, hole);
            next_remaining.extend(after_subtract);
        }

        remaining = next_remaining;
    }

    remaining
}

/// Check if two Rect2 intersect.
fn rects_intersect(a: Rect2, b: Rect2) -> bool {
    a.position.x < b.position.x + b.size.x
        && a.position.x + a.size.x > b.position.x
        && a.position.y < b.position.y + b.size.y
        && a.position.y + a.size.y > b.position.y
}
