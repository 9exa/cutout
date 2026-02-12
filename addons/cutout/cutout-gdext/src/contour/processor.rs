//! ContourProcessor - Batch processing API for contour detection
//!
//! This module provides high-level APIs for processing multiple images with
//! different settings, handling all downscaling/upscaling and grid conversion.

use godot::prelude::*;
use godot::classes::Image;
use godot::builtin::VarDictionary as Dictionary;
use super::grid::Grid;
use super::settings::ContourSettings;
use super::moore_neighbour;
use super::marching_squares;

/// Main processor for batch contour detection
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct ContourProcessor {
    #[base]
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for ContourProcessor {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl ContourProcessor {
    /// Process multiple images with uniform settings
    ///
    /// # Arguments
    /// * `images` - Array of images to process
    /// * `algorithm` - Algorithm to use (0 = Moore, 1 = Marching Squares)
    /// * `alpha_threshold` - Alpha threshold for solid pixels
    /// * `max_resolution` - Maximum resolution (0 = no limit)
    ///
    /// # Returns
    /// Array of contour arrays (one per image)
    #[func]
    pub fn calculate_batch_uniform(
        &self,
        images: Array<Gd<Image>>,
        algorithm: i32,
        alpha_threshold: f32,
        max_resolution: i32,
    ) -> Array<Variant> {
        let mut results = Array::new();

        for image in images.iter_shared() {
            let contours = self.process_single_image(
                &image,
                algorithm,
                alpha_threshold,
                max_resolution,
            );
            let contour_array = Self::to_godot_array(contours);
            results.push(&contour_array.to_variant());
        }

        results
    }

    /// Process multiple images with individual settings
    ///
    /// # Arguments
    /// * `images` - Array of images to process
    /// * `settings` - Array of ContourSettings (must match images length)
    ///
    /// # Returns
    /// Array of contour arrays (one per image)
    #[func]
    pub fn calculate_batch(
        &self,
        images: Array<Gd<Image>>,
        settings: Array<Gd<ContourSettings>>,
    ) -> Array<Variant> {
        if images.len() != settings.len() {
            godot_error!(
                "Image count ({}) doesn't match settings count ({})",
                images.len(),
                settings.len()
            );
            return Array::new();
        }

        let mut results = Array::new();

        for i in 0..images.len() {
            if let (Some(image), Some(setting)) = (images.get(i), settings.get(i)) {
                let setting_bind = setting.bind();

                let contours = self.process_single_image(
                    &image,
                    setting_bind.algorithm,
                    setting_bind.alpha_threshold,
                    setting_bind.max_resolution,
                );
                let contour_array = Self::to_godot_array(contours);
                results.push(&contour_array.to_variant());
            }
        }

        results
    }

    /// Process multiple images with settings from dictionaries
    ///
    /// # Arguments
    /// * `images` - Array of images to process
    /// * `settings` - Array of Dictionaries with keys: algorithm, alpha_threshold, max_resolution
    ///
    /// # Returns
    /// Array of contour arrays (one per image)
    #[func]
    pub fn calculate_batch_dict(
        &self,
        images: Array<Gd<Image>>,
        settings: Array<Variant>,
    ) -> Array<Variant> {
        if images.len() != settings.len() {
            godot_error!(
                "Image count ({}) doesn't match settings count ({})",
                images.len(),
                settings.len()
            );
            return Array::new();
        }

        let mut results = Array::new();

        for i in 0..images.len() {
            if let (Some(image), Some(dict_variant)) = (images.get(i), settings.get(i)) {
                let dict = dict_variant.try_to::<Dictionary>().unwrap_or_else(|_| Dictionary::new());

                // Extract settings from dictionary with defaults
                let algorithm = dict
                    .get("algorithm")
                    .map(|v| v.try_to::<i32>().unwrap_or(1))
                    .unwrap_or(1);
                let alpha_threshold = dict
                    .get("alpha_threshold")
                    .map(|v| v.try_to::<f32>().unwrap_or(0.5))
                    .unwrap_or(0.5);
                let max_resolution = dict
                    .get("max_resolution")
                    .map(|v| v.try_to::<i32>().unwrap_or(0))
                    .unwrap_or(0);

                let contours = self.process_single_image(
                    &image,
                    algorithm,
                    alpha_threshold,
                    max_resolution,
                );
                let contour_array = Self::to_godot_array(contours);
                results.push(&contour_array.to_variant());
            }
        }

        results
    }
}

impl ContourProcessor {
    /// Process a single image with given settings
    ///
    /// Handles downscaling, grid conversion, algorithm dispatch, and upscaling
    fn process_single_image(
        &self,
        image: &Gd<Image>,
        algorithm: i32,
        alpha_threshold: f32,
        max_resolution: i32,
    ) -> Vec<Vec<Vector2>> {
        let width = image.get_width();
        let height = image.get_height();
        let max_dim = width.max(height);

        // Check if downscaling is needed
        let needs_downscaling = max_resolution > 0 && max_dim > max_resolution;
        let scale_factor = if needs_downscaling {
            max_resolution as f32 / max_dim as f32
        } else {
            1.0
        };

        // Downscale image if needed
        let working_image = if needs_downscaling {
            let new_width = (width as f32 * scale_factor) as i32;
            let new_height = (height as f32 * scale_factor) as i32;

            let mut resized = image.clone();
            resized.resize(new_width, new_height);
            resized
        } else {
            image.clone()
        };

        // Create grid from (possibly downscaled) image
        let grid = Grid::from_image(&working_image, alpha_threshold);

        // Dispatch to appropriate algorithm
        let mut contours = match algorithm {
            0 => moore_neighbour::calculate(&grid),
            1 => marching_squares::calculate(&grid),
            _ => {
                godot_error!("Unknown algorithm: {}, defaulting to Marching Squares", algorithm);
                marching_squares::calculate(&grid)
            }
        };

        // Upscale contour points if we downscaled
        if needs_downscaling {
            let upscale_factor = 1.0 / scale_factor;
            for contour in &mut contours {
                for point in contour {
                    point.x *= upscale_factor;
                    point.y *= upscale_factor;
                }
            }
        }

        contours
    }

    /// Convert Vec<Vec<Vector2>> to Godot Array<Variant>
    fn to_godot_array(contours: Vec<Vec<Vector2>>) -> Array<Variant> {
        let mut result = Array::new();

        for contour in contours {
            let mut packed = PackedVector2Array::new();
            for point in contour {
                packed.push(point);
            }
            result.push(&packed.to_variant());
        }

        result
    }
}
