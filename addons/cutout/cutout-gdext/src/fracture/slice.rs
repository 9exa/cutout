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

// Segment encoded as a 2-element PackedVector2Array [point_a, point_b].
type Segment = (Vector2, Vector2);

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
            if h.len() >= 3 {
                Some(h)
            } else {
                None
            }
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

// ============================================================================
// Multi-slice implementation with segment generation
// ============================================================================

// Pattern enum matching GDScript
#[repr(i32)]
#[derive(Debug, Clone, Copy)]
pub enum SlicePattern {
    Radial = 0,
    Parallel = 1,
    Grid = 2,
    Chaotic = 3,
}

impl From<i32> for SlicePattern {
    fn from(v: i32) -> Self {
        match v {
            0 => SlicePattern::Radial,
            1 => SlicePattern::Parallel,
            2 => SlicePattern::Grid,
            3 => SlicePattern::Chaotic,
            _ => SlicePattern::Chaotic,
        }
    }
}

/// Simple xorshift RNG matching GDScript's RandomNumberGenerator behavior
struct SimpleRng {
    state: u64,
}

impl SimpleRng {
    fn new(seed: i64) -> Self {
        // Match GDScript's seed initialization
        let mut state = if seed == 0 { 1 } else { seed.abs() as u64 };
        // Warm up
        for _ in 0..4 {
            state ^= state << 13;
            state ^= state >> 17;
            state ^= state << 5;
        }
        Self { state }
    }

    fn randf(&mut self) -> f32 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 17;
        self.state ^= self.state << 5;
        (self.state as f32 / u64::MAX as f32)
    }

    fn randf_range(&mut self, from: f32, to: f32) -> f32 {
        from + self.randf() * (to - from)
    }
}

/// Bisect a single outer polygon along a line, returning the resulting pieces.
/// No hole handling — used for intermediate slices.
fn bisect_outer(outer: &[Vector2], line_start: Vector2, line_end: Vector2) -> Vec<Vec<Vector2>> {
    let intersections = find_polygon_intersections(outer, line_start, line_end);
    if intersections.len() < 2 {
        return vec![outer.to_vec()]; // line misses, keep as-is
    }

    let bounds = calculate_bounds(outer);
    let margin = (bounds.size.x + bounds.size.y) * 0.5;

    let dir = (line_end - line_start).normalized();
    let normal = Vector2::new(-dir.y, dir.x);

    let left_clip = build_half_plane_rect(line_start, line_end, normal, margin);
    let right_clip = build_half_plane_rect(line_start, line_end, -normal, margin);

    let mut pieces = clipper2_intersect(outer, &left_clip);
    pieces.extend(clipper2_intersect(outer, &right_clip));
    pieces.retain(|p| p.len() >= 3);
    pieces
}

/// Generate slice segments based on pattern
fn generate_pattern_segments(
    pattern: SlicePattern,
    outer: &[Vector2],
    rng: &mut SimpleRng,
    slice_count: i32,
    // Pattern-specific parameters
    origin: Option<Vector2>,
    radial_randomness: f32,
    parallel_angle: f32,
    parallel_angle_rand: f32,
    grid_h_start: f32,
    grid_v_start: f32,
    grid_h_slices: i32,
    grid_v_slices: i32,
    grid_h_random: f32,
    grid_v_random: f32,
    grid_h_angle_rand: f32,
    grid_v_angle_rand: f32,
) -> Vec<Segment> {
    let bounds = calculate_bounds(outer);
    let center = bounds.center();
    let max_extent = bounds.size.x.max(bounds.size.y);

    let mut segments = Vec::new();

    match pattern {
        SlicePattern::Radial => {
            let origin = origin.unwrap_or(center);
            let angle_step = std::f32::consts::TAU / slice_count as f32;

            for i in 0..slice_count {
                let mut angle = i as f32 * angle_step;
                if radial_randomness > 0.0 {
                    let max_deviation = angle_step * radial_randomness * 0.5;
                    angle += rng.randf_range(-max_deviation, max_deviation);
                }

                let dir = Vector2::new(angle.cos(), angle.sin());
                segments.push((
                    origin - dir * max_extent,
                    origin + dir * max_extent,
                ));
            }
        },
        SlicePattern::Parallel => {
            let base_angle = parallel_angle.to_radians();
            let spacing = max_extent * 2.0 / (slice_count + 1) as f32;
            let max_angle_deviation = (45.0 * parallel_angle_rand).to_radians();

            for i in 1..=slice_count {
                let mut angle = base_angle;
                if parallel_angle_rand > 0.0 {
                    angle += rng.randf_range(-max_angle_deviation, max_angle_deviation);
                }

                let dir = Vector2::new(angle.cos(), angle.sin());
                let perp = Vector2::new(-dir.y, dir.x);
                let offset = perp * (i as f32 * spacing - max_extent);

                segments.push((
                    center + offset - dir * max_extent,
                    center + offset + dir * max_extent,
                ));
            }
        },
        SlicePattern::Grid => {
            let h_spacing = bounds.size.x / (grid_h_slices + 1) as f32;
            let v_spacing = bounds.size.y / (grid_v_slices + 1) as f32;

            // Vertical lines
            for i in 0..grid_h_slices {
                let mut x = grid_h_start + (i + 1) as f32 * h_spacing;
                if grid_h_random > 0.0 {
                    let max_jitter = h_spacing * grid_h_random * 0.5;
                    x += rng.randf_range(-max_jitter, max_jitter);
                }

                let mut angle = 90.0_f32.to_radians();
                if grid_h_angle_rand > 0.0 {
                    let max_angle_deviation = (45.0 * grid_h_angle_rand).to_radians();
                    angle += rng.randf_range(-max_angle_deviation, max_angle_deviation);
                }

                let dir = Vector2::new(angle.cos(), angle.sin());
                let line_center = Vector2::new(x, center.y);

                segments.push((
                    line_center - dir * max_extent,
                    line_center + dir * max_extent,
                ));
            }

            // Horizontal lines
            for i in 0..grid_v_slices {
                let mut y = grid_v_start + (i + 1) as f32 * v_spacing;
                if grid_v_random > 0.0 {
                    let max_jitter = v_spacing * grid_v_random * 0.5;
                    y += rng.randf_range(-max_jitter, max_jitter);
                }

                let mut angle = 0.0_f32;
                if grid_v_angle_rand > 0.0 {
                    let max_angle_deviation = (45.0 * grid_v_angle_rand).to_radians();
                    angle += rng.randf_range(-max_angle_deviation, max_angle_deviation);
                }

                let dir = Vector2::new(angle.cos(), angle.sin());
                let line_center = Vector2::new(center.x, y);

                segments.push((
                    line_center - dir * max_extent,
                    line_center + dir * max_extent,
                ));
            }
        },
        SlicePattern::Chaotic => {
            for _ in 0..slice_count {
                let angle = rng.randf() * std::f32::consts::TAU;
                let dir = Vector2::new(angle.cos(), angle.sin());
                let offset = Vector2::new(
                    rng.randf_range(-max_extent * 0.5, max_extent * 0.5),
                    rng.randf_range(-max_extent * 0.5, max_extent * 0.5),
                );

                segments.push((
                    center + offset - dir * max_extent,
                    center + offset + dir * max_extent,
                ));
            }
        },
    }

    segments
}

/// Apply multi-slice fracture to polygon
fn apply_slices(
    outer: &[Vector2],
    holes: &[Vec<Vector2>],
    segments: &[Segment],
) -> Array<PackedVector2Array> {
    // Iteratively slice the outer polygon only
    let mut current: Vec<Vec<Vector2>> = vec![outer.to_vec()];

    for &(a, b) in segments {
        let mut next: Vec<Vec<Vector2>> = Vec::new();
        for fragment in &current {
            let pieces = bisect_outer(fragment, a, b);
            next.extend(pieces);
        }
        if !next.is_empty() {
            current = next;
        }
    }

    // Subtract holes once from the final fragment set
    let mut result = Array::new();
    for fragment in &current {
        for piece in subtract_all_holes(fragment, holes) {
            if piece.len() >= 3 {
                let mut packed = PackedVector2Array::new();
                for p in &piece {
                    packed.push(*p);
                }
                result.push(&packed);
            }
        }
    }

    result
}

/// Fracture polygons using radial pattern
pub fn fracture_slices_radial(
    polygons: &Array<PackedVector2Array>,
    seed: i64,
    slice_count: i32,
    origin: Vector2,
    radial_randomness: f32,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let mut rng = SimpleRng::new(seed);
    let origin_opt = if origin == Vector2::ZERO { None } else { Some(origin) };

    let segments = generate_pattern_segments(
        SlicePattern::Radial,
        &outer,
        &mut rng,
        slice_count,
        origin_opt,
        radial_randomness,
        0.0, 0.0, // parallel params
        0.0, 0.0, // grid start
        0, 0,     // grid slices
        0.0, 0.0, // grid random
        0.0, 0.0, // grid angle rand
    );

    if segments.is_empty() {
        return polygons.clone();
    }

    let result = apply_slices(&outer, &holes, &segments);
    if result.is_empty() {
        return polygons.clone();
    }
    result
}

/// Fracture polygons using parallel pattern
pub fn fracture_slices_parallel(
    polygons: &Array<PackedVector2Array>,
    seed: i64,
    slice_count: i32,
    parallel_angle: f32,
    parallel_angle_rand: f32,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let mut rng = SimpleRng::new(seed);

    let segments = generate_pattern_segments(
        SlicePattern::Parallel,
        &outer,
        &mut rng,
        slice_count,
        None,
        0.0, // radial_randomness
        parallel_angle,
        parallel_angle_rand,
        0.0, 0.0, // grid start
        0, 0,     // grid slices
        0.0, 0.0, // grid random
        0.0, 0.0, // grid angle rand
    );

    if segments.is_empty() {
        return polygons.clone();
    }

    let result = apply_slices(&outer, &holes, &segments);
    if result.is_empty() {
        return polygons.clone();
    }
    result
}

/// Fracture polygons using grid pattern
pub fn fracture_slices_grid(
    polygons: &Array<PackedVector2Array>,
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
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let mut rng = SimpleRng::new(seed);

    let segments = generate_pattern_segments(
        SlicePattern::Grid,
        &outer,
        &mut rng,
        0, // slice_count not used for grid
        None,
        0.0, // radial_randomness
        0.0, 0.0, // parallel params
        grid_h_start,
        grid_v_start,
        grid_h_slices,
        grid_v_slices,
        grid_h_random,
        grid_v_random,
        grid_h_angle_rand,
        grid_v_angle_rand,
    );

    if segments.is_empty() {
        return polygons.clone();
    }

    let result = apply_slices(&outer, &holes, &segments);
    if result.is_empty() {
        return polygons.clone();
    }
    result
}

/// Fracture polygons using chaotic pattern
pub fn fracture_slices_chaotic(
    polygons: &Array<PackedVector2Array>,
    seed: i64,
    slice_count: i32,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let mut rng = SimpleRng::new(seed);

    let segments = generate_pattern_segments(
        SlicePattern::Chaotic,
        &outer,
        &mut rng,
        slice_count,
        None,
        0.0, // radial_randomness
        0.0, 0.0, // parallel params
        0.0, 0.0, // grid start
        0, 0,     // grid slices
        0.0, 0.0, // grid random
        0.0, 0.0, // grid angle rand
    );

    if segments.is_empty() {
        return polygons.clone();
    }

    let result = apply_slices(&outer, &holes, &segments);
    if result.is_empty() {
        return polygons.clone();
    }
    result
}

/// Fracture polygons using manually provided slice segments
pub fn fracture_slices_manual(
    polygons: &Array<PackedVector2Array>,
    segments: &Array<PackedVector2Array>,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() || segments.is_empty() {
        return polygons.clone();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    // Decode segments from 2-point arrays
    let mut decoded_segments = Vec::new();
    for i in 0..segments.len() {
        let seg = segments.get(i).unwrap();
        if seg.len() >= 2 {
            decoded_segments.push((seg.get(0).unwrap(), seg.get(1).unwrap()));
        }
    }

    if decoded_segments.is_empty() {
        return polygons.clone();
    }

    let result = apply_slices(&outer, &holes, &decoded_segments);
    if result.is_empty() {
        return polygons.clone();
    }
    result
}

/// Optimized parallel slice fracture with projection-bound culling
pub fn fracture_slices_parallel_optimized(
    polygons: &Array<PackedVector2Array>,
    seed: i64,
    slice_count: i32,
    parallel_angle: f32,
    parallel_angle_rand: f32,
) -> Array<PackedVector2Array> {
    if polygons.is_empty() {
        return Array::new();
    }

    let outer: Vec<Vector2> = polygons.get(0).unwrap().to_vec();
    if outer.len() < 3 {
        return Array::new();
    }

    let holes: Vec<Vec<Vector2>> = (1..polygons.len())
        .filter_map(|i| {
            let h: Vec<Vector2> = polygons.get(i).unwrap().to_vec();
            if h.len() >= 3 { Some(h) } else { None }
        })
        .collect();

    let bounds = calculate_bounds(&outer);
    let center = bounds.center();
    let max_extent = bounds.size.x.max(bounds.size.y);

    let base_angle = parallel_angle.to_radians();
    let max_angle_deviation = (45.0 * parallel_angle_rand).to_radians();

    let base_dir = Vector2::new(base_angle.cos(), base_angle.sin());
    let base_perp = Vector2::new(-base_dir.y, base_dir.x);
    let spacing = max_extent * 2.0 / (slice_count + 1) as f32;

    // Generate segments with RNG
    let mut rng = SimpleRng::new(seed);
    let mut segments = Vec::new();
    for i in 1..=slice_count {
        let mut angle = base_angle;
        if parallel_angle_rand > 0.0 {
            angle += rng.randf_range(-max_angle_deviation, max_angle_deviation);
        }

        let dir = Vector2::new(angle.cos(), angle.sin());
        let perp = Vector2::new(-dir.y, dir.x);
        let offset = perp * (i as f32 * spacing - max_extent);

        segments.push((
            center + offset - dir * max_extent,
            center + offset + dir * max_extent,
        ));
    }

    // Conservative projection bounds closure
    let conservative_bounds = |poly: &[Vector2], base_perp: Vector2, max_dev: f32| -> (f32, f32) {
        if max_dev == 0.0 {
            let projs: Vec<f32> = poly.iter().map(|p| p.dot(base_perp)).collect();
            let min = projs.iter().cloned().fold(f32::INFINITY, f32::min);
            let max = projs.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
            return (min, max);
        }
        let mut min = f32::INFINITY;
        let mut max = f32::NEG_INFINITY;
        for angle_offset in [0.0_f32, -max_dev, max_dev] {
            let cos_a = angle_offset.cos();
            let sin_a = angle_offset.sin();
            let test_perp = Vector2::new(
                base_perp.x * cos_a - base_perp.y * sin_a,
                base_perp.x * sin_a + base_perp.y * cos_a,
            );
            for p in poly {
                let proj = p.dot(test_perp);
                min = min.min(proj);
                max = max.max(proj);
            }
        }
        (min, max)
    };

    // Apply optimized slicing with projection culling
    let (init_min, init_max) = conservative_bounds(&outer, base_perp, max_angle_deviation);
    let mut remaining: Vec<Vec<Vector2>> = vec![outer];
    let mut min_projs: Vec<f32> = vec![init_min];
    let mut max_projs: Vec<f32> = vec![init_max];
    let mut output: Vec<Vec<Vector2>> = Vec::new();

    let margin_factor = max_angle_deviation.sin().abs() * 0.1;

    for (seg_a, seg_b) in segments {
        let seg_center = (seg_a + seg_b) * 0.5;
        let slice_proj = seg_center.dot(base_perp);
        let bounds_extent = {
            let all: Vec<f32> = remaining
                .iter()
                .flat_map(|poly| poly.iter().map(|p| p.dot(base_perp)))
                .collect();
            if all.is_empty() {
                1.0_f32
            } else {
                all.iter().cloned().fold(f32::NEG_INFINITY, f32::max)
                    - all.iter().cloned().fold(f32::INFINITY, f32::min)
            }
        };
        let slice_proj_min = slice_proj - margin_factor * bounds_extent;
        let slice_proj_max = slice_proj + margin_factor * bounds_extent;

        let mut new_remaining: Vec<Vec<Vector2>> = Vec::new();
        let mut new_min_projs: Vec<f32> = Vec::new();
        let mut new_max_projs: Vec<f32> = Vec::new();

        for j in 0..remaining.len() {
            if min_projs[j] > slice_proj_max {
                new_remaining.push(remaining[j].clone());
                new_min_projs.push(min_projs[j]);
                new_max_projs.push(max_projs[j]);
            } else if max_projs[j] < slice_proj_min {
                output.push(remaining[j].clone());
            } else {
                let pieces = bisect_outer(&remaining[j], seg_a, seg_b);
                for piece in pieces {
                    if piece.len() >= 3 {
                        let (mn, mx) = conservative_bounds(&piece, base_perp, max_angle_deviation);
                        new_remaining.push(piece);
                        new_min_projs.push(mn);
                        new_max_projs.push(mx);
                    }
                }
            }
        }

        remaining = new_remaining;
        min_projs = new_min_projs;
        max_projs = new_max_projs;
    }

    output.extend(remaining);

    // Subtract holes once from all final fragments
    let mut result = Array::new();
    for fragment in &output {
        for piece in subtract_all_holes(fragment, &holes) {
            if piece.len() >= 3 {
                let mut packed = PackedVector2Array::new();
                for p in &piece {
                    packed.push(*p);
                }
                result.push(&packed);
            }
        }
    }

    if result.is_empty() {
        return polygons.clone();
    }
    result
}
