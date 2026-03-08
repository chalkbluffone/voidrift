shader_type canvas_item;

// Power-up pickup — glowing circle with pulsing aura and unicode symbol overlay.
// Per-type color via uniform. Renders a circular shape with soft glow edge.

uniform vec4 powerup_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.5, 4.0) = 2.0;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.0;
uniform float pulse_min : hint_range(0.5, 1.0) = 0.7;
uniform float pulse_max : hint_range(1.0, 1.5) = 1.2;
uniform float ring_width : hint_range(0.01, 0.15) = 0.06;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);

	// Pulse animation
	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));

	// Core filled circle — bright center fading toward edge
	float core_radius = 0.35 * pulse;
	float core_mask = smoothstep(core_radius, core_radius * 0.3, dist);

	// Soft glow halo beyond core
	float glow_mask = smoothstep(0.5, 0.1, dist) * 0.4;

	// Crisp outer ring
	float ring_dist = abs(dist - 0.38 * pulse);
	float ring_mask = smoothstep(ring_width, ring_width * 0.3, ring_dist) * 0.6;

	// Inner shimmer (subtle radial sparkle)
	float angle = atan(uv.y, uv.x);
	float shimmer = pow(abs(sin(angle * 6.0 + TIME * 3.0)), 12.0) * 0.2;
	shimmer *= smoothstep(0.4, 0.1, dist);

	vec3 neon = powerup_color.rgb;

	// Combine layers
	vec3 final_rgb = neon * core_mask * glow_intensity;
	final_rgb += neon * glow_mask * glow_intensity * 0.5;
	final_rgb += neon * ring_mask * glow_intensity;
	final_rgb += neon * shimmer * glow_intensity;

	float final_alpha = clamp(core_mask + glow_mask + ring_mask + shimmer * 0.3, 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
