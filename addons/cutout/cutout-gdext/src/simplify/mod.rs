//! Polygon simplification algorithms for reducing vertex count
//!
//! Currently, polygon simplification is implemented in GDScript for maintainability.
//! The algorithms are fast enough in GDScript for typical use cases (100-1000 points).
//!
//! Available GDScript implementations:
//! - CutoutPolysimpRDP - Ramer-Douglas-Peucker (distance-based)
//! - CutoutPolysimpVW - Visvalingam-Whyatt (area-based)
//! - CutoutPolysimpRW - Reumann-Witkam (perpendicular distance)
//!
//! Rust implementations may be added in the future if profiling shows
//! simplification as a performance bottleneck.