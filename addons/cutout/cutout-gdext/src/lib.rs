use godot::prelude::*;

// Module declarations
pub(crate) mod common;
pub mod contour;
pub mod fracture;
pub mod simplify;

struct CutoutExtension;

#[gdextension]
unsafe impl ExtensionLibrary for CutoutExtension {}

/// Simple test class to verify the extension loads correctly
#[derive(GodotClass)]
#[class(base=RefCounted)]
struct CutoutNative {
    #[base]
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for CutoutNative {
    fn init(base: Base<RefCounted>) -> Self {
        godot_print!("Cutout native extension initialized!");
        Self { base }
    }
}

#[godot_api]
impl CutoutNative {
    /// Test method to verify the extension is working
    #[func]
    fn hello_cutout(&self) -> GString {
        GString::from("Hello from Rust GDExtension!")
    }

    /// Get version information
    #[func]
    fn get_version(&self) -> GString {
        GString::from(env!("CARGO_PKG_VERSION"))
    }
}
