shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 col = vec4(0.0, 0.0, 0.0, 1.0);
	col.r = sin(UV.x * PI * 30.0 + 0.5 * UV.y + 4.0 * TIME);
	
	ALBEDO = col.rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
