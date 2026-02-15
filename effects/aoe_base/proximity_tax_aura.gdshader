shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 aura_color : source_color = vec4(1.0, 0.93, 0.35, 0.12);
uniform vec4 ring_color : source_color = vec4(1.0, 0.95, 0.45, 0.75);
uniform float radius_px = 90.0;
uniform float ring_width_px = 2.0;
uniform float glow_width_px = 10.0;
uniform float glow_strength : hint_range(0.0, 1.5) = 0.45;
uniform vec2 quad_size_px = vec2(220.0, 220.0);

void fragment() {
	vec2 local_px = (UV - vec2(0.5)) * quad_size_px;
	float dist = length(local_px);

	float fill_mask = 1.0 - smoothstep(radius_px - 1.0, radius_px + 0.5, dist);
	float ring_half = ring_width_px * 0.5;
	float ring_mask = 1.0 - smoothstep(ring_half, ring_half + 1.0, abs(dist - radius_px));
	float outside = max(dist - radius_px, 0.0);
	float glow_mask = (1.0 - smoothstep(0.0, glow_width_px, outside)) * glow_strength;

	float alpha = aura_color.a * fill_mask;
	alpha = max(alpha, ring_color.a * ring_mask);
	alpha = max(alpha, ring_color.a * glow_mask * 0.7);

	vec3 color = aura_color.rgb;
	color = mix(color, ring_color.rgb, clamp(ring_mask + glow_mask * 0.5, 0.0, 1.0));

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
