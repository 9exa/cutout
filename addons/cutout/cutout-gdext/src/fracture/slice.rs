//! Line-based polygon slicing algorithm
//!
//! Reference GDScript: addons/cutout/resources/destruction/cutout_destruction_slice.gd
//!
//! This algorithm works by:
//! 1. Extending the slice line to fully cross the polygon
//! 2. Using clipper2 to clip the polygon against each half-plane of the line
//! 3. Handling holes by including them in both halves

use super::geometry::calculate_bounds;
use clipper2::*;
use godot::prelude::*;

/// Fracture polygons along a line segment.
///
/// # Arguments
/// * `polygons` - First = outer boundary, rest = holes
/// * `line_start` - Start point of the slice line
/// * `line_end` - End point of the slice line
///
/// # Returns
/// Array of polygon fragments (typically 2 halves, or original if line misses)
pub fn fracture(
    polygons: &Array<PackedVector2Array>,
    line_start: Vector2,
    line_end: Vector2,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    // Find intersections of the slice line with the outer polygon
    let intersections = find_polygon_intersections(&outer, line_start, line_end);

    if intersections.len() < 2 {
        // Line doesn't fully cross the polygon - return original
        return polygons.clone();
    }

    // Build two half-plane clipping polygons from the slice line
    let bounds = calculate_bounds(&outer);
    let margin = (bounds.size.x + bounds.size.y) * 0.5; // generous margin

    let dir = (line_end - line_start).normalized();
    let normal = Vector2::new(-dir.y, dir.x); // perpendicular

    // Create large clipping rectangles on each side of the line
    let left_clip = build_half_plane_rect(line_start, line_end, normal, margin);
    let right_clip = build_half_plane_rect(line_start, line_end, -normal, margin);

    // Clip outer polygon against each half
    let left_fragments = clipper2_intersect(&outer, &left_clip);
    let right_fragments = clipper2_intersect(&outer, &right_clip);

    // Collect holes for subtraction
    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let mut result = Array::new();

    // Process each side's fragments, subtracting holes
    for fragments in [&left_fragments, &right_fragments] {
        for fragment in fragments {
            if fragment.len() < 3 {
                continue;
            }

            let final_pieces = subtract_all_holes(fragment, &holes);
            for piece in final_pieces {
                if piece.len() >= 3 {
                    let mut packed = PackedVector2Array::new();
                    for p in &piece {
                        packed.push(*p);
                    }
                    result.push(&packed);
                }
            }
        }
    }

    if result.is_empty() {
        return polygons.clone();
    }

    result
}

/// Find all intersection points between a line segment and polygon edges.
fn find_polygon_intersections(
    polygon: &[Vector2],
    line_start: Vector2,
    line_end: Vector2,
) -> Vec<Vector2> {
    let mut intersections = Vec::new();
    let n = polygon.len();

    for i in 0..n {
        let edge_start = polygon[i];
        let edge_end = polygon[(i + 1) % n];

        if let Some(point) = line_segment_intersection(line_start, line_end, edge_start, edge_end) {
            intersections.push(point);
        }
    }

    intersections
}

/// Find intersection point of two line segments, if it exists.
fn line_segment_intersection(
    a1: Vector2,
    a2: Vector2,
    b1: Vector2,
    b2: Vector2,
) -> Option<Vector2> {
    let d1 = a2 - a1;
    let d2 = b2 - b1;

    let cross = d1.x * d2.y - d1.y * d2.x;

    // Parallel or coincident
    if cross.abs() < 1e-10 {
        return None;
    }

    let d = b1 - a1;
    let t = (d.x * d2.y - d.y * d2.x) / cross;
    let u = (d.x * d1.y - d.y * d1.x) / cross;

    // Check if intersection is within both segments
    if (0.0..=1.0).contains(&t) && (0.0..=1.0).contains(&u) {
        Some(a1 + d1 * t)
    } else {
        None
    }
}

/// Build a large rectangle representing one side of a line.
fn build_half_plane_rect(
    line_start: Vector2,
    line_end: Vector2,
    normal: Vector2,
    extent: f32,
) -> Vec<Vector2> {
    let dir = (line_end - line_start).normalized();

    // Extend the line well beyond the polygon
    let extended_start = line_start - dir * extent;
    let extended_end = line_end + dir * extent;

    // Build a rectangle on the normal side
    vec![
        extended_start,
        extended_end,
        extended_end + normal * extent,
        extended_start + normal * extent,
    ]
}

// ============================================================================
// Clipper2 helpers (same pattern as voronoi.rs)
// ============================================================================

fn to_clipper_path(polygon: &[Vector2]) -> Vec<(f64, f64)> {
    polygon.iter().map(|p| (p.x as f64, p.y as f64)).collect()
}

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

fn clipper2_intersect(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match intersect(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(_) => Vec::new(),
    }
}

fn clipper2_difference(subject: &[Vector2], clip: &[Vector2]) -> Vec<Vec<Vector2>> {
    let subject_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(subject)];
    let clip_paths: Vec<Vec<(f64, f64)>> = vec![to_clipper_path(clip)];

    match difference(subject_paths, clip_paths, FillRule::NonZero) {
        Ok(result) => from_clipper_paths(result),
        Err(_) => vec![subject.to_vec()],
    }
}

fn subtract_all_holes(fragment: &[Vector2], holes: &[Vec<Vector2>]) -> Vec<Vec<Vector2>> {
    let mut remaining = vec![fragment.to_vec()];

    for hole in holes {
        let mut next_remaining = Vec::new();
        for piece in &remaining {
            let after = clipper2_difference(piece, hole);
            next_remaining.extend(after);
        }
        remaining = next_remaining;
    }

    remaining
}
