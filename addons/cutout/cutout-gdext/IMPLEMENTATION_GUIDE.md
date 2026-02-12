# Cutout Rust Implementation Guide

This guide explains the file hierarchy and what needs to be implemented in each module.

## File Hierarchy

```
cutout-gdext/src/
├── lib.rs                          # ✅ Extension entry point (done)
├── contour/                        # Contour detection algorithms
│   ├── mod.rs                      # ✅ Module interface (done)
│   ├── marching_squares.rs         # ⏳ TODO: Implement Marching Squares
│   └── moore_neighbour.rs          # ⏳ TODO: Implement Moore Neighbor
├── simplify/                       # Polygon simplification algorithms
│   ├── mod.rs                      # ✅ Module interface (done)
│   ├── rdp.rs                      # ⏳ TODO: Implement RDP
│   └── visvalingam_whyatt.rs       # ⏳ TODO: Implement Visvalingam-Whyatt
└── fracture/                       # Destruction/fracturing algorithms
    ├── mod.rs                      # ✅ Module interface (done)
    ├── voronoi.rs                  # ⏳ TODO: Implement Voronoi (PARALLEL!)
    └── slice.rs                    # ⏳ TODO: Implement Slice
```

## Implementation Order (Recommended)

### Phase 1: Simple Algorithms (Start Here)
1. **RDP** (`simplify/rdp.rs`) - Good starting point, pure math, no image processing
2. **Slice** (`fracture/slice.rs`) - Straightforward line-polygon intersection

### Phase 2: Image Processing
3. **Moore Neighbor** (`contour/moore_neighbour.rs`) - Simpler than Marching Squares
4. **Marching Squares** (`contour/marching_squares.rs`) - More complex, sub-pixel accuracy

### Phase 3: Complex Algorithms
5. **Visvalingam-Whyatt** (`simplify/visvalingam_whyatt.rs`) - Requires priority queue
6. **Voronoi** (`fracture/voronoi.rs`) - Most complex, but most rewarding (parallelism!)

---

## Algorithm Details

### 1. RDP (Ramer-Douglas-Peucker)
**File:** `simplify/rdp.rs`
**GDScript Reference:** `addons/cutout/resources/polysimp/cutout_polysimp_rdp.gd`

**What it does:** Simplifies polygons by removing points within `epsilon` distance from line segments.

**Key concepts:**
- Recursive algorithm
- Perpendicular distance calculation
- Point-to-line distance formula

**Implementation hints:**
```rust
fn perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> f32 {
    let line_vec = line_end - line_start;
    let point_vec = point - line_start;

    let line_len_sq = line_vec.length_squared();
    if line_len_sq == 0.0 {
        return point_vec.length();
    }

    let projection = point_vec.dot(line_vec) / line_len_sq;
    let projection = projection.clamp(0.0, 1.0);
    let closest_point = line_start + line_vec * projection;

    (point - closest_point).length()
}
```

---

### 2. Slice Destruction
**File:** `fracture/slice.rs`
**GDScript Reference:** `addons/cutout/resources/destruction/cutout_destruction_slice.gd`

**What it does:** Cuts a polygon along a line, creating two separate pieces.

**Key concepts:**
- Line segment intersection
- Point classification (left/right of line)
- Polygon splitting

**Implementation hints:**
```rust
fn line_segment_intersection(
    a1: Vector2, a2: Vector2,
    b1: Vector2, b2: Vector2
) -> Option<Vector2> {
    let s1 = a2 - a1;
    let s2 = b2 - b1;

    let s = (-s1.y * (a1.x - b1.x) + s1.x * (a1.y - b1.y)) /
            (-s2.x * s1.y + s1.x * s2.y);
    let t = ( s2.x * (a1.y - b1.y) - s2.y * (a1.x - b1.x)) /
            (-s2.x * s1.y + s1.x * s2.y);

    if s >= 0.0 && s <= 1.0 && t >= 0.0 && t <= 1.0 {
        Some(a1 + s1 * t)
    } else {
        None
    }
}
```

---

### 3. Moore Neighbor Tracing
**File:** `contour/moore_neighbour.rs`
**GDScript Reference:** `addons/cutout/resources/contour/cutout_contour_moore_neighbour.gd`

**What it does:** Traces the boundary of solid pixels by checking 8 neighbors.

**Key concepts:**
- BitMap conversion (alpha threshold)
- 8-directional neighbor checking
- Boundary following

**Implementation hints:**
```rust
const DIRECTIONS: [(i32, i32); 8] = [
    (-1, 0),  // W
    (-1, -1), // NW
    (0, -1),  // N
    (1, -1),  // NE
    (1, 0),   // E
    (1, 1),   // SE
    (0, 1),   // S
    (-1, 1),  // SW
];

fn is_solid(image: &Gd<Image>, x: i32, y: i32, threshold: f32) -> bool {
    if x < 0 || y < 0 || x >= image.get_width() || y >= image.get_height() {
        return false;
    }
    image.get_pixel(x, y).a >= threshold
}
```

---

### 4. Marching Squares
**File:** `contour/marching_squares.rs`
**GDScript Reference:** `addons/cutout/resources/contour/cutout_contour_marching_squares.gd`

**What it does:** Creates smooth contours with sub-pixel accuracy using a lookup table.

**Key concepts:**
- 16 cell configurations (2^4 corners)
- Edge interpolation
- Contour tracing

**Edge table reference:**
```rust
// Each cell has 4 corners: TL, TR, BR, BL
// Configuration is a 4-bit number (0-15)
// Edge indices: TOP=0, RIGHT=1, BOTTOM=2, LEFT=3

const EDGE_TABLE: [[i32; 4]; 16] = [
    [-1, -1, -1, -1], // 0000: All empty
    [3, 2, -1, -1],   // 0001: BL solid
    [1, 2, -1, -1],   // 0010: BR solid
    [1, 3, -1, -1],   // 0011: Bottom solid
    // ... (see GDScript for full table)
];
```

---

### 5. Visvalingam-Whyatt
**File:** `simplify/visvalingam_whyatt.rs`
**GDScript Reference:** `addons/cutout/resources/polysimp/cutout_polysimp_vw.gd`

**What it does:** Simplifies polygons by iteratively removing points with smallest effective area.

**Key concepts:**
- Effective area (triangle formed by point and neighbors)
- Priority queue (min-heap)
- Iterative removal

**Implementation hints:**
```rust
use std::collections::BinaryHeap;
use std::cmp::Reverse;

fn triangle_area(a: Vector2, b: Vector2, c: Vector2) -> f32 {
    ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs() * 0.5
}

struct PointWithArea {
    index: usize,
    area: f32,
}

// Use BinaryHeap with Reverse for min-heap
```

---

### 6. Voronoi Fracturing ⭐ (PARALLEL!)
**File:** `fracture/voronoi.rs`
**GDScript Reference:** `addons/cutout/resources/destruction/cutout_destruction_voronoi.gd`

**What it does:** Breaks polygons into irregular pieces using Voronoi diagrams.

**Key concepts:**
- Delaunay triangulation (use `delaunator` crate)
- Voronoi diagram (dual of Delaunay)
- Polygon clipping
- **Parallel processing with Rayon!**

**Implementation hints:**
```rust
use delaunator::{triangulate, Point};
use rayon::prelude::*;

// Generate seed points
fn generate_random_seeds(bounds: Rect2, count: i32, seed: u64) -> Vec<Vector2> {
    // Use a seeded RNG for reproducibility
    use rand::{SeedableRng, Rng};
    use rand::rngs::StdRng;

    let mut rng = StdRng::seed_from_u64(seed);
    (0..count)
        .map(|_| Vector2::new(
            rng.gen_range(bounds.min.x..bounds.max.x),
            rng.gen_range(bounds.min.y..bounds.max.y)
        ))
        .collect()
}

// Delaunay triangulation
fn compute_delaunay(points: &[Vector2]) -> delaunator::Triangulation {
    let delaunay_points: Vec<Point> = points.iter()
        .map(|p| Point { x: p.x as f64, y: p.y as f64 })
        .collect();

    triangulate(&delaunay_points)
}

// PARALLEL BATCH PROCESSING!
pub fn fracture_batch(&self, batch: Array<Array<PackedVector2Array>>) -> Array<Array<PackedVector2Array>> {
    // Convert to Vec for rayon
    let batch_vec: Vec<_> = (0..batch.len())
        .map(|i| batch.get(i))
        .collect();

    // Process in parallel
    let results: Vec<_> = batch_vec.par_iter()
        .map(|polygons| self.fracture(polygons.clone()))
        .collect();

    // Convert back to Godot Array
    let result_array = Array::new();
    for result in results {
        result_array.push(result);
    }
    result_array
}
```

---

## Testing Each Algorithm

After implementing each algorithm, test it with the existing GDScript test scenes:

### RDP
```gdscript
# In Godot console or test script
var rdp = RDPNative.new()
rdp.epsilon = 2.0
var polygon = PackedVector2Array([...])
var simplified = rdp.simplify(polygon)
print("Original: ", polygon.size(), " -> Simplified: ", simplified.size())
```

### Marching Squares
```gdscript
var ms = MarchingSquaresNative.new()
ms.alpha_threshold = 0.5
var texture = load("res://addons/cutout/demo_project/siobhan.png")
var image = texture.get_image()
var contours = ms.calculate_boundary(image)
print("Found ", contours.size(), " contours")
```

### Voronoi (with parallelism!)
```gdscript
var voronoi = VoronoiDestructionNative.new()
voronoi.seed_count = 10

# Single destruction
var polygons = [outer_polygon]
var fragments = voronoi.fracture(polygons)

# BATCH - process 50 destructions in parallel!
var batch = []
for i in range(50):
    batch.append([outer_polygon])
var all_fragments = voronoi.fracture_batch(batch)
# This will use all CPU cores!
```

---

## Performance Expectations

| Algorithm | GDScript | Rust (Expected) | Speedup |
|-----------|----------|-----------------|---------|
| RDP | ~5ms | ~0.05ms | 100x |
| Moore Neighbor | ~20ms | ~0.2ms | 100x |
| Marching Squares | ~30ms | ~0.3ms | 100x |
| Voronoi (single) | ~150ms | ~2ms | 75x |
| Voronoi (batch 50) | ~7500ms | ~100ms | 75x (+ parallel!) |

---

## Debugging Tips

1. **Start simple:** Test with tiny polygons (4-5 points) first
2. **Print intermediate values:** Use `godot_print!()` liberally
3. **Visual debugging:** Draw results in Godot to verify correctness
4. **Compare with GDScript:** Run both implementations side-by-side
5. **Use Rust tests:** Add `#[cfg(test)]` modules for unit tests

---

## Resources

- **Godot-Rust Book:** https://godot-rust.github.io/
- **Delaunator crate:** https://docs.rs/delaunator/
- **Rayon docs:** https://docs.rs/rayon/
- **GDScript reference:** Check the corresponding files in `addons/cutout/resources/`

---

Good luck with your implementation! Start with RDP and work your way up. The satisfaction of seeing 50+ destructions happen instantly in parallel will be worth it! 🦀
