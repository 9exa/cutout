//! Polygon fracturing/destruction algorithms
//!
//! This module provides:
//! - `CutoutDestructionProcessor` - Stateless Godot API for fracture operations
//! - Voronoi fracturing - Break polygons into irregular pieces using Voronoi diagrams
//! - Slice fracturing - Cut polygons along lines
//! - Seed generation - 5 distribution patterns for Voronoi cell placement

pub mod geometry;
pub mod processor;
pub mod seeds;
pub mod slice;
pub mod voronoi;

pub use processor::CutoutDestructionProcessor;
