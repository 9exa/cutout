//! CutoutContourProcessor - Batch processing API for contour detection
//!
//! This module provides high-level APIs for processing multiple images with
//! different settings, handling all downscaling/upscaling and grid conversion.

use super::grid::create_grid_from_image;
use super::marching_squares;
use super::moore_neighbour;
use super::settings::{ContourSettings, NO_RESOLUTION_LIMIT};
use godot::builtin::VarDictionary as Dictionary;
use godot::classes::image::Format;
use godot::classes::Image;
use godot::prelude::*;

/// Main processor for batch contour detection
///
/// This is a stateless utility class providing static methods for contour detection.
/// All methods can be called directly without instantiation.
#[derive(GodotClass)]
#[class(no_init)]
pub struct CutoutContourProcessor;

#[godot_api]
impl CutoutContourProcessor {
    /// Process multiple images with uniform settings
    ///
    /// # Arguments
    /// * `images` - Array of images to process
    /// * `algorithm` - Algorithm to use (0 = Moore, 1 = Marching Squares)
    /// * `alpha_threshold` - Alpha threshold for solid pixels
    /// * `max_resolution` - Maximum resolution (NO_RESOLUTION_LIMIT = no limit)
    ///
    /// # Returns
    /// Array of contour arrays (one per image)
    #[func]
    pub fn calculate_batch_uniform(
        images: Array<Gd<Image>>,
        algorithm: i32,
        alpha_threshold: f32,
        max_resolution: Vector2,
    ) -> Array<Variant> {
        let mut results = Array::new();

        for image in images.iter_shared() {
            let contours = Self::process_single_image(&image, algorithm, alpha_threshold, max_resolution);
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

                let contours = Self::process_single_image(
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
                let dict = dict_variant
                    .try_to::<Dictionary>()
                    .unwrap_or_else(|_| Dictionary::new());

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
                    .map(|v| v.try_to::<Vector2>().unwrap_or(NO_RESOLUTION_LIMIT))
                    .unwrap_or(NO_RESOLUTION_LIMIT);

                let contours =
                    Self::process_single_image(&image, algorithm, alpha_threshold, max_resolution);
                let contour_array = Self::to_godot_array(contours);
                results.push(&contour_array.to_variant());
            }
        }

        results
    }
}

impl CutoutContourProcessor {
    /// Process a single image with given settings
    ///
    /// Handles downscaling, grid conversion, algorithm dispatch, and upscaling
    fn process_single_image(
        image: &Gd<Image>,
        algorithm: i32,
        alpha_threshold: f32,
        max_resolution: Vector2,
    ) -> Vec<Vec<Vector2>> {
        let width = image.get_width();
        let height = image.get_height();

        // Check if downscaling is needed (max_resolution components < 0 means no limit)
        let needs_x_downscale = max_resolution.x > 0.0 && width as f32 > max_resolution.x;
        let needs_y_downscale = max_resolution.y > 0.0 && height as f32 > max_resolution.y;
        let needs_downscaling = needs_x_downscale || needs_y_downscale;

        // Calculate scale factors for each dimension independently
        let scale_x = if needs_x_downscale {
            max_resolution.x / width as f32
        } else {
            1.0
        };
        let scale_y = if needs_y_downscale {
            max_resolution.y / height as f32
        } else {
            1.0
        };

        // Use the smaller scale factor to ensure both dimensions stay within limits
        let scale_factor = scale_x.min(scale_y);

        // Deep-copy the image so we never mutate the caller's original.
        // `Gd::clone()` only increments the ref-count for RefCounted types,
        // so we must use `duplicate_resource()` to get an independent copy.
        let mut working_image = image.duplicate_resource();

        if needs_downscaling {
            let new_width = (width as f32 * scale_factor) as i32;
            let new_height = (height as f32 * scale_factor) as i32;
            working_image.resize(new_width, new_height);
        }

        working_image.decompress();
        working_image.convert(Format::RGBA8);

        // Create grid from prepared image (single get_data() FFI call internally)
        let grid = create_grid_from_image(&working_image, alpha_threshold);

        // Dispatch to appropriate algorithm
        let mut contours = match algorithm {
            0 => moore_neighbour::calculate(&grid),
            1 => marching_squares::calculate(&grid),
            _ => {
                godot_error!(
                    "Unknown algorithm: {}, defaulting to Marching Squares",
                    algorithm
                );
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
    fn to_godot_array(contours: Vec<Vec<Vector2>>) -> Array<PackedVector2Array> {
        let mut result = Array::new();

        for contour in contours {
            let mut packed = PackedVector2Array::new();
            for point in contour {
                packed.push(point);
            }
            result.push(&packed);
        }

        result
    }
}
