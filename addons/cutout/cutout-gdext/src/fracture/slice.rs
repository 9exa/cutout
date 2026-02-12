//! Line-based polygon slicing algorithm
//!
//! Reference GDScript: addons/cutout/resources/destruction/cutout_destruction_slice.gd
//!
//! This algorithm works by:
//! 1. Taking a line segment (start + end points)
//! 2. Finding intersections with polygon edges
//! 3. Splitting the polygon along the line
//! 4. Returning two separate polygons (left and right of the line)

use godot::prelude::*;


#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct SliceDestructionNative {
    #[base]
    base: Base<RefCounted>,

    #[var]
    pub slice_start: Vector2,

    #[var]
    pub slice_end: Vector2,
}

#[godot_api]
impl IRefCounted for SliceDestructionNative {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            slice_start: Vector2::ZERO,
            slice_end: Vector2::new(1.0, 0.0),
        }
    }
}

#[godot_api]
impl SliceDestructionNative {
    /// Slice polygons along a line
    #[func]
    pub fn fracture(&self, polygons: Array<PackedVector2Array>) -> Array<PackedVector2Array> {
        // TODO: Implement slice algorithm
        //
        // Steps:
        // 1. Extract outer polygon
        // 2. Find all intersection points between slice line and polygon edges
        // 3. If < 2 intersections, return original polygon (no cut)
        // 4. Sort intersection points along the slice line
        // 5. Split polygon into left and right sides:
        //    - Walk around polygon, inserting intersection points
        //    - Create two new polygons at the cut
        // 6. Handle holes separately (clip to each side)
        // 7. Return both fragments
        //
        // Reference: See GDScript implementation and CutoutGeometryUtils.bisect_polygon

        polygons
    }

    /// Set the slice line
    #[func]
    pub fn set_slice_line(&mut self, start: Vector2, end: Vector2) {
        self.slice_start = start;
        self.slice_end = end;
    }
}

// Note: Trait implementation can be added later if needed
// impl DestructionAlgorithm for SliceDestructionNative {
//     fn fracture(&self, polygons: Array<PackedVector2Array>) -> Array<PackedVector2Array> {
//         self.fracture(polygons)
//     }
// }

// TODO: Helper functions to implement:
// - line_segment_intersection(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Option<Vector2>
// - find_polygon_intersections(polygon: &[Vector2], line_start: Vector2, line_end: Vector2) -> Vec<(usize, Vector2)>
// - point_side_of_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> f32  // <0 left, >0 right
// - split_polygon_at_intersections(polygon: &[Vector2], intersections: &[(usize, Vector2)]) -> (Vec<Vector2>, Vec<Vector2>)
