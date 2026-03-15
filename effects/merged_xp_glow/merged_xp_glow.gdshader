shader_type canvas_item;

// XP pickup glow shader for normal and merged XP visuals.
// Uses a square SDF glow that can be tinted per scene.

uniform float glow_intensity : hint_range(0.5, 4.0) = 2.5;
uniform vec4 glow_color : source_color = vec4(0.97, 0.02, 0.81, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;

	// Square SDF: max of abs components (Chebyshev distance)
	float box_dist = max(abs(uv.x), abs(uv.y));

	// Solid core square
	float core_mask = smoothstep(0.28, 0.20, box_dist);

	// Soft glow halo extending beyond core
	float glow_mask = smoothstep(0.5, 0.10, box_dist) * 0.45;

	vec3 final_rgb = glow_color.rgb * (core_mask + glow_mask) * glow_intensity;
	float final_alpha = clamp(core_mask + glow_mask, 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
