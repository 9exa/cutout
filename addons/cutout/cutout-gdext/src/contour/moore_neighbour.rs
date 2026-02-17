//! Moore Neighbor contour detection algorithm
//!
//! Reference GDScript: addons/cutout/resources/contour/cutout_contour_moore_neighbour.gd
//!
//! This algorithm works by:
//! 1. Taking a pre-built binary grid (solid/empty based on alpha)
//! 2. Finding the bottommost-leftmost solid pixel as starting point
//! 3. Tracing the boundary clockwise using Moore neighborhood (8 directions)
//! 4. Stopping when returning to the starting pixel

use super::grid::*;
use godot::prelude::*;

const NEIGHBOR_DIRECTIONS: [Vector2i; 8] = [
    Vector2i::new(-1, 0),  // 0: W
    Vector2i::new(-1, -1), // 1: NW
    Vector2i::new(0, -1),  // 2: N
    Vector2i::new(1, -1),  // 3: NE
    Vector2i::new(1, 0),   // 4: E
    Vector2i::new(1, 1),   // 5: SE
    Vector2i::new(0, 1),   // 6: S
    Vector2i::new(-1, 1),  // 7: SW
];

/// Maximum iterations to prevent infinite loops in pathological cases
const MAX_CONTOUR_POINTS: usize = 1_000_000;

/// Pure Rust function for Moore Neighbor contour detection
///
/// # Arguments
/// * `grid` - Binary grid of solid/empty pixels
///
/// # Returns
/// Vector of contours, each contour is a vector of points
pub fn calculate(grid: &Grid) -> Vec<Vec<Vector2>> {
    let Some(start_pixel) = first_bottom_left_solid_pixel(grid) else {
        return Vec::new(); // No solid pixels, return empty contour list
    };

    let mut visited = vec![vec![false; grid.width()]; grid.height()];
    let mut points = vec![start_pixel];
    let mut current_pixel = start_pixel;
    let mut last_dir = 0; // Start searching from W (index 0), so next iteration starts at 1

    const N_DIRECTIONS: usize = NEIGHBOR_DIRECTIONS.len();

    // Do at least one iteration to find the first neighbor
    for i in 0..N_DIRECTIONS {
        let dir_idx = (last_dir + 1 + i) % N_DIRECTIONS;
        let dir = NEIGHBOR_DIRECTIONS[dir_idx];
        let next_pixel = Vector2::new(
            current_pixel.x + dir.x as f32,
            current_pixel.y + dir.y as f32,
        );

        let nx = next_pixel.x as i32;
        let ny = next_pixel.y as i32;

        if nx >= 0 && nx < grid.width() as i32 && ny >= 0 && ny < grid.height() as i32 {
            if let Some(&true) = grid.get_at(nx as usize, ny as usize) {
                current_pixel = next_pixel;
                points.push(current_pixel);
                visited[ny as usize][nx as usize] = true;
                last_dir = dir_idx;
                break;
            }
        }
    }

    // Continue tracing until we return to the start pixel
    while current_pixel != start_pixel && points.len() < MAX_CONTOUR_POINTS {
        let mut found_next = false;

        for i in 0..N_DIRECTIONS {
            let dir_idx = (last_dir + 1 + i) % N_DIRECTIONS;
            let dir = NEIGHBOR_DIRECTIONS[dir_idx];
            let next_pixel = Vector2::new(
                current_pixel.x + dir.x as f32,
                current_pixel.y + dir.y as f32,
            );

            let nx = next_pixel.x as i32;
            let ny = next_pixel.y as i32;

            if nx >= 0 && nx < grid.width() as i32 && ny >= 0 && ny < grid.height() as i32 {
                let nxu = nx as usize;
                let nyu = ny as usize;

                if !visited[nyu][nxu] && grid.get_at(nxu, nyu) == Some(&true) {
                    current_pixel = next_pixel;
                    points.push(current_pixel);
                    visited[nyu][nxu] = true;
                    // record the incoming direction
                    last_dir = dir_idx + N_DIRECTIONS / 2;
                    found_next = true;
                    break;
                }
            }
        }

        if !found_next {
            break; // No unvisited solid neighbor found, stop tracing
        }
    }

    vec![points]
}
