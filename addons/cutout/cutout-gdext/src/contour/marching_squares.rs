//! Marching Squares contour detection algorithm
//!
//! Reference GDScript: addons/cutout/resources/contour/cutout_contour_marching_squares.gd
//!
//! This algorithm works by:
//! 1. Treating the image as a grid of squares
//! 2. Each square has 4 corners that are either "solid" or "empty" based on alpha threshold
//! 3. The 16 possible configurations determine which edges to trace
//! 4. Edges are interpolated for sub-pixel accuracy

use super::grid::Grid;
use godot::prelude::*;
use std::collections::{HashMap, HashSet};

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Edge {
    Top,
    Right,
    Bottom,
    Left,
}

type EdgeSegment = (Edge, Edge);

const SEGMENT_EMPTY: [EdgeSegment; 0] = [];
const SEGMENT_BL_ONLY: [EdgeSegment; 1] = [(Edge::Left, Edge::Bottom)];
const SEGMENT_BR_ONLY: [EdgeSegment; 1] = [(Edge::Bottom, Edge::Right)];
const SEGMENT_BL_BR: [EdgeSegment; 1] = [(Edge::Left, Edge::Right)];
const SEGMENT_TR_ONLY: [EdgeSegment; 1] = [(Edge::Right, Edge::Top)];
const SEGMENT_TR_BL: [EdgeSegment; 2] = [(Edge::Left, Edge::Top), (Edge::Bottom, Edge::Right)];
const SEGMENT_TR_BR: [EdgeSegment; 1] = [(Edge::Bottom, Edge::Top)];
const SEGMENT_TR_BR_BL: [EdgeSegment; 1] = [(Edge::Left, Edge::Top)];
const SEGMENT_TL_ONLY: [EdgeSegment; 1] = [(Edge::Top, Edge::Left)];
const SEGMENT_TL_BL: [EdgeSegment; 1] = [(Edge::Top, Edge::Bottom)];
const SEGMENT_TL_BR: [EdgeSegment; 2] = [(Edge::Top, Edge::Right), (Edge::Left, Edge::Bottom)];
const SEGMENT_TL_BR_BL: [EdgeSegment; 1] = [(Edge::Top, Edge::Right)];
const SEGMENT_TL_TR: [EdgeSegment; 1] = [(Edge::Right, Edge::Left)];
const SEGMENT_TL_TR_BL: [EdgeSegment; 1] = [(Edge::Right, Edge::Bottom)];
const SEGMENT_TL_TR_BR: [EdgeSegment; 1] = [(Edge::Bottom, Edge::Left)];

// Segment Start-stop points for each variant of cell
const SEGMENT_LOOKUP: [&[EdgeSegment]; 16] = [
    &SEGMENT_EMPTY,    // 0: 0000
    &SEGMENT_BL_ONLY,  // 1: 0001
    &SEGMENT_BR_ONLY,  // 2: 0010
    &SEGMENT_BL_BR,    // 3: 0011
    &SEGMENT_TR_ONLY,  // 4: 0100
    &SEGMENT_TR_BL,    // 5: 0101
    &SEGMENT_TR_BR,    // 6: 0110
    &SEGMENT_TR_BR_BL, // 7: 0111
    &SEGMENT_TL_ONLY,  // 8: 1000
    &SEGMENT_TL_BL,    // 9: 1001
    &SEGMENT_TL_BR,    // 10: 1010
    &SEGMENT_TL_BR_BL, // 11: 1011
    &SEGMENT_TL_TR,    // 12: 1100
    &SEGMENT_TL_TR_BL, // 13: 1101
    &SEGMENT_TL_TR_BR, // 14: 1110
    &SEGMENT_EMPTY,    // 15: 1111 (Full)
];

/// Pure Rust function for Marching Squares contour detection
///
/// # Arguments
/// * `grid` - Binary grid of solid/empty pixels
///
/// # Returns
/// Vector of contours, each contour is a vector of points
pub fn calculate(grid: &Grid) -> Vec<Vec<Vector2>> {
    let segments = generate_segments(grid);
    let mut contours = chain_segments(segments);

    // Largest contours first as they are more likely to be the 'fill', with smaller contours being
    // holes
    contours.sort_by(|a, b| b.len().cmp(&a.len()));

    contours
}

// Generate all line segments from bitmap
fn generate_segments(grid: &Grid) -> Vec<(Vector2i, Vector2i)> {
    let mut segments = vec![];

    let width = grid.width() as i32;
    let height = grid.height() as i32;

    // Each cell has the top left and bottom right corners ((x, y), (x + 1, y + 1))
    // Iterate from -1 to width/height to catch edges on all sides of boundary pixels
    for cy in -1..height {
        for cx in -1..width {
            let tl = grid.get(cx, cy).unwrap_or(&false);
            let tr = grid.get(cx + 1, cy).unwrap_or(&false);
            let br = grid.get(cx + 1, cy + 1).unwrap_or(&false);
            let bl = grid.get(cx, cy + 1).unwrap_or(&false);

            let config = (if *tl { 8 } else { 0 })
                | (if *tr { 4 } else { 0 })
                | (if *br { 2 } else { 0 })
                | (if *bl { 1 } else { 0 });

            let cell_segments = SEGMENT_LOOKUP[config as usize];
            segments.extend(cell_segments.iter().map(|(start_edge, end_edge)| {
                let start_point = edge_to_point(cx, cy, *start_edge);
                let end_point = edge_to_point(cx, cy, *end_edge);
                (start_point, end_point)
            }));
        }
    }

    segments
}

// The point in space of the edge of the cell, multiplied by 2 for HashMap key compatibility
fn edge_to_point(cx: i32, cy: i32, edge: Edge) -> Vector2i {
    match edge {
        Edge::Top => Vector2i::new(cx * 2 + 1, cy * 2),
        Edge::Right => Vector2i::new(cx * 2 + 2, cy * 2 + 1),
        Edge::Bottom => Vector2i::new(cx * 2 + 1, cy * 2 + 2),
        Edge::Left => Vector2i::new(cx * 2, cy * 2 + 1),
    }
}

fn chain_segments(segments_doubled: Vec<(Vector2i, Vector2i)>) -> Vec<Vec<Vector2>> {
    let max_iter = segments_doubled.len(); // Prevent infinite loops, should be
                                           // enough for all segments

    // Build a map from points to their connected segments
    // pointkey -> [connected point keys]
    let mut adjacency: HashMap<(i32, i32), Vec<(i32, i32)>> = HashMap::new();
    let mut visited: HashSet<(i32, i32)> = HashSet::new();

    for (start, end) in segments_doubled {
        let start_key = (start.x, start.y);
        let end_key = (end.x, end.y);
        adjacency.entry(start_key).or_default().push(end_key);
        adjacency.entry(end_key).or_default().push(start_key);
    }

    let mut contours: Vec<Vec<Vector2>> = Vec::new();

    for (start_key, _) in adjacency.iter() {
        if visited.contains(start_key) {
            continue;
        }

        let mut current_key = start_key;
        let mut contour: Vec<Vector2> = vec![Vector2::new(
            start_key.0 as f32 / 2.0,
            start_key.1 as f32 / 2.0,
        )];

        // not uncommon for images to be more than 2000k pixels, so don't use recursion or we might
        // hit stack overflow
        for _ in 0..max_iter {
            visited.insert(*current_key);
            let Some(neighbours) = adjacency.get(current_key) else {
                break; // Malformed segments, restart
            };
            let next_key = neighbours.iter().find(|&&n| !visited.contains(&n));
            if let Some(next_key) = next_key {
                contour.push(Vector2::new(
                    next_key.0 as f32 / 2.0,
                    next_key.1 as f32 / 2.0,
                ));
                current_key = next_key;
            } else {
                break; // No unvisited neighbours, end of contour
            }
        }

        if contour.len() > 2 {
            contours.push(contour);
        }
    }

    contours
}
