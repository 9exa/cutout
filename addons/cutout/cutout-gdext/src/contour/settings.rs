//! ContourSettings resource for configuring contour detection
//!
//! This resource allows per-image configuration of contour detection parameters
//! including algorithm choice, alpha threshold, and maximum resolution.

use godot::prelude::*;

/// Constant representing no resolution limit
pub const NO_RESOLUTION_LIMIT: Vector2 = Vector2::new(-1.0, -1.0);

/// Configuration settings for contour detection
#[derive(GodotClass)]
#[class(base=Resource)]
pub struct ContourSettings {
    #[base]
    base: Base<Resource>,

    /// Algorithm to use: 0 = Moore Neighbour, 1 = Marching Squares
    #[export]
    #[var]
    pub algorithm: i32,

    /// Alpha threshold for determining solid pixels (0.0 - 1.0)
    #[export]
    #[var]
    pub alpha_threshold: f32,

    /// Maximum resolution for downscaling (NO_RESOLUTION_LIMIT = no limit)
    #[export]
    #[var]
    pub max_resolution: Vector2,
}

#[godot_api]
impl IResource for ContourSettings {
    fn init(base: Base<Resource>) -> Self {
        Self {
            base,
            algorithm: 1,                        // Default to Marching Squares
            alpha_threshold: 0.5,                // Default threshold
            max_resolution: NO_RESOLUTION_LIMIT, // No downscaling by default
        }
    }
}

#[godot_api]
impl ContourSettings {
    /// Create a new ContourSettings with custom values
    #[func]
    pub fn create(algorithm: i32, alpha_threshold: f32, max_resolution: Vector2) -> Gd<Self> {
        Gd::from_init_fn(|base| Self {
            base,
            algorithm,
            alpha_threshold,
            max_resolution,
        })
    }
}
