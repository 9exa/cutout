//! Shared geometry utilities for fracture algorithms
//!
//! Provides common geometric operations used across voronoi, slice, and seed
//! generation: point-in-polygon testing, bounding boxes, polygon area, and
//! half-plane clipping.

use godot::prelude::*;

/// Calculate the bounding rectangle of a polygon.
pub fn calculate_bounds(polygon: &[Vector2]) -> Rect2 {
    if polygon.is_empty() {
        return Rect2::new(Vector2::ZERO, Vector2::ZERO);
    }

    let mut min_x = polygon[0].x;
    let mut max_x = polygon[0].x;
    let mut min_y = polygon[0].y;
    let mut max_y = polygon[0].y;

    for p in polygon.iter().skip(1) {
        min_x = min_x.min(p.x);
        max_x = max_x.max(p.x);
        min_y = min_y.min(p.y);
        max_y = max_y.max(p.y);
    }

    Rect2::new(
        Vector2::new(min_x, min_y),
        Vector2::new(max_x - min_x, max_y - min_y),
    )
}

/// Calculate the signed area of a polygon using the shoelace formula.
///
/// Positive area indicates CCW winding, negative indicates CW winding.
pub fn polygon_area(polygon: &[Vector2]) -> f32 {
    let n = polygon.len();
    if n < 3 {
        return 0.0;
    }

    let mut area = 0.0;
    for i in 0..n {
        let j = (i + 1) % n;
        area += polygon[i].x * polygon[j].y;
        area -= polygon[j].x * polygon[i].y;
    }

    area * 0.5
}

/// Check if a point is inside a polygon using ray casting.
pub fn point_in_polygon(point: Vector2, polygon: &[Vector2]) -> bool {
    let n = polygon.len();
    if n < 3 {
        return false;
    }

    let mut inside = false;
    let mut p1 = polygon[0];

    for i in 1..=n {
        let p2 = polygon[i % n];

        if point.y > p1.y.min(p2.y) {
            if point.y <= p1.y.max(p2.y) {
                if point.x <= p1.x.max(p2.x) {
                    if p1.y != p2.y {
                        let xinters = (point.y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x;
                        if p1.x == p2.x || point.x <= xinters {
                            inside = !inside;
                        }
                    }
                }
            }
        }

        p1 = p2;
    }

    inside
}

/// Clip a polygon against a half-plane defined by a point and normal.
///
/// Keeps the side of the polygon in the direction of the normal.
/// Uses the Sutherland-Hodgman algorithm for a single edge.
pub fn clip_polygon_to_half_plane(
    polygon: &[Vector2],
    plane_point: Vector2,
    plane_normal: Vector2,
) -> Vec<Vector2> {
    if polygon.len() < 3 {
        return Vec::new();
    }

    let mut clipped = Vec::new();
    let n = polygon.len();

    for i in 0..n {
        let current = polygon[i];
        let next = polygon[(i + 1) % n];

        let current_dist = (current - plane_point).dot(plane_normal);
        let next_dist = (next - plane_point).dot(plane_normal);

        let current_inside = current_dist >= 0.0;
        let next_inside = next_dist >= 0.0;

        if current_inside {
            clipped.push(current);
        }

        // If edge crosses the plane, add intersection point
        if current_inside != next_inside {
            let t = current_dist / (current_dist - next_dist);
            let intersection = current.lerp(next, t);
            clipped.push(intersection);
        }
    }

    clipped
}

/// Calculate the circumcenter of a triangle (equidistant from all 3 vertices).
///
/// Returns `None` if the triangle is degenerate (collinear points).
pub fn circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Option<Vector2> {
    let d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));

    if d.abs() < 0.0001 {
        return None;
    }

    let a_sq = a.x * a.x + a.y * a.y;
    let b_sq = b.x * b.x + b.y * b.y;
    let c_sq = c.x * c.x + c.y * c.y;

    let ux = (a_sq * (b.y - c.y) + b_sq * (c.y - a.y) + c_sq * (a.y - b.y)) / d;
    let uy = (a_sq * (c.x - b.x) + b_sq * (a.x - c.x) + c_sq * (b.x - a.x)) / d;

    Some(Vector2::new(ux, uy))
}

/// Check if a point is far enough from all existing points.
pub fn is_far_enough(point: Vector2, existing: &[Vector2], min_distance: f32) -> bool {
    let min_dist_sq = min_distance * min_distance;
    for p in existing {
        if (point - *p).length_squared() < min_dist_sq {
            return false;
        }
    }
    true
}

/// Grow (or shrink) a Rect2 by a given amount on all sides.
///
/// Positive values expand, negative values shrink.
pub fn grow_rect(rect: Rect2, amount: f32) -> Rect2 {
    let pos = rect.position - Vector2::new(amount, amount);
    let size = rect.size + Vector2::new(amount * 2.0, amount * 2.0);

    // Clamp to avoid negative sizes
    let size = Vector2::new(size.x.max(0.0), size.y.max(0.0));

    Rect2::new(pos, size)
}
