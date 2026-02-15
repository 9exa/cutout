//! Moore Neighbor contour detection algorithm
//!
//! Reference GDScript: addons/cutout/resources/contour/cutout_contour_moore_neighbour.gd
//!
//! This algorithm works by:
//! 1. Converting the image to a bitmap (binary: solid/empty based on alpha)
//! 2. Finding the topmost-leftmost solid pixel as starting point
//! 3. Tracing the boundary clockwise using Moore neighborhood (8 directions)
//! 4. Stopping when returning to the starting pixel

use super::algorithm::ContourAlgorithm;
use super::grid::Grid;
use godot::classes::Image;
use godot::prelude::*;

const NEIGHBOR_DIRECTIONS: [Vector2i; 8] = [
    Vector2i::new(-1, 0),  // W
    Vector2i::new(-1, -1), // NW
    Vector2i::new(0, -1),  // N
    Vector2i::new(1, -1),  // NE
    Vector2i::new(1, 0),   // E
    Vector2i::new(1, 1),   // SE
    Vector2i::new(0, 1),   // S
    Vector2i::new(-1, 1),  // SW
];

pub struct MooreNeighboour;

impl ContourAlgorithm for MooreNeighboour {
    fn calculate_boundary(
        image: &Image,
        alpha_threshold: f32,
        _max_resolution: Vector2,
    ) -> Vec<Vec<Vector2>> {
        let bitmap = Grid::from_image(image, alpha_threshold);
        let visited = Grid::new(bitmap.width(), bitmap.height());
    }
}

// TODO: Implement Moore Neighbor algorithm
//
// Steps:
// 1. Convert image to BitMap based on alpha_threshold
// 3. Initialize boundary array and visited tracking
// 4. Start tracing:
//    - Check 8 neighbors in clockwise order (Moore neighborhood)
//    - Move to next solid pixel that hasn't been visited
//    - Add current pixel to boundary
//    - Stop when back at starting pixel
// 5. Return array containing the single contour
//
// Reference: See GDScript implementation for DIRECTIONS constant

// Note: Trait implementation can be added later if needed
// impl ContourAlgorithm for MooreNeighbourNative {
//     fn calculate_boundary(&self, image: Gd<Image>) -> Array<PackedVector2Array> {
//         self.calculate_boundary(image)
//     }
// }

// TODO: Define Moore neighborhood directions (8 neighbors)
// const DIRECTIONS: [(i32, i32); 8] = [
//     (-1, 0),  // W
//     (-1, -1), // NW
//     (0, -1),  // N
//     (1, -1),  // NE
//     (1, 0),   // E
//     (1, 1),   // SE
//     (0, 1),   // S
//     (-1, 1),  // SW
// ];

// TODO: Helper functions to implement:
// - image_to_bitmap(image: &Image, threshold: f32) -> BitMap
// - find_start_pixel(bitmap: &BitMap) -> Option<(i32, i32)>
// - is_solid(bitmap: &BitMap, x: i32, y: i32) -> bool
// - get_next_neighbor(current: (i32, i32), last_dir: usize, bitmap: &BitMap) -> Option<((i32, i32), usize)>
