shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Main texture (foreground) - typically your sprite/cutout texture
uniform sampler2D foreground_texture : source_color;

// Background texture or color - shown where foreground alpha is 0
uniform sampler2D background_texture : source_color;
uniform vec4 background_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Controls whether to use background texture (true) or background color (false)
uniform bool use_background_texture = false;

// Optional: Control for texture filtering
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Sample the foreground texture
	vec4 foreground = texture(foreground_texture, UV);

	// Get background color or texture
	vec4 background;
	if (use_background_texture) {
		background = texture(background_texture, UV);
	} else {
		background = background_color;
	}

	// Composite: blend background and foreground based on foreground alpha
	// When foreground.a = 0, show 100% background
	// When foreground.a = 1, show 100% foreground
	vec4 final_color = mix(background, foreground, foreground.a);

	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;

	// Optional: Alpha scissor for hard cutoff
	if (alpha_scissor > 0.0 && ALPHA < alpha_scissor) {
		discard;
	}
}
