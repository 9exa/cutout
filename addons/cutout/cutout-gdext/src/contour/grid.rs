//! Grid alias and urtilites for contour detection
//!
//! Grid is a type alias for Grid2D<bool>, providing a binary grid representation
//! for image data with efficient boundary checking and pixel access.

use crate::common::Grid2D;

pub type Grid = Grid2D<bool>;

pub fn first_bottom_left_solid_pixel(grid: &Grid) -> Option<(usize, usize)> {
    for y in (0..grid.height()).rev() {
        for x in 0..grid.width() {
            if let Some(&true) = grid.get_at(x, y) {
                return Some((x, y));
            }
        }
    }
    None
}
