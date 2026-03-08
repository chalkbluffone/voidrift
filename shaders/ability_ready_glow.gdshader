shader_type canvas_item;

// Ready-state glow for the captain ability ring indicator.
// Pulsing core, shimmer sparkle, and synthwave color cycling (magenta/cyan/purple).

uniform float glow_intensity : hint_range(0.5, 6.0) = 1.5;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.0;
uniform float color_cycle_speed : hint_range(0.2, 4.0) = 0.8;
uniform float circle_radius : hint_range(0.1, 0.5) = 0.35;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);

	// Synthwave color cycling: magenta → cyan → purple → magenta
	float cycle = TIME * color_cycle_speed;
	vec3 col_a = vec3(1.0, 0.08, 0.58);  // Magenta
	vec3 col_b = vec3(0.0, 1.0, 0.9);    // Cyan
	vec3 col_c = vec3(0.55, 0.1, 1.0);   // Purple
	float t = fract(cycle / 3.0) * 3.0;
	vec3 neon;
	if (t < 1.0) {
		neon = mix(col_a, col_b, t);
	} else if (t < 2.0) {
		neon = mix(col_b, col_c, t - 1.0);
	} else {
		neon = mix(col_c, col_a, t - 2.0);
	}

	// Pulse animation
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);

	// Soft glow halo around the circle edge
	float glow_start = circle_radius * pulse;
	float glow_mask = smoothstep(glow_start + 0.2, glow_start * 0.6, dist) * 0.35;

	// Crisp ring at circle edge
	float ring_center = circle_radius * pulse;
	float ring_dist = abs(dist - ring_center);
	float ring_mask = smoothstep(0.04, 0.01, ring_dist) * 0.5;

	// Shimmer sparkle (angular pattern)
	float angle = atan(uv.y, uv.x);
	float shimmer = pow(abs(sin(angle * 8.0 + TIME * 4.0)), 16.0) * 0.3;
	shimmer *= smoothstep(glow_start + 0.15, glow_start * 0.5, dist);

	// Second shimmer layer (counter-rotating)
	float shimmer2 = pow(abs(sin(angle * 5.0 - TIME * 2.5)), 20.0) * 0.15;
	shimmer2 *= smoothstep(glow_start + 0.1, glow_start * 0.7, dist);

	// Combine layers
	vec3 final_rgb = neon * glow_mask * glow_intensity;
	final_rgb += neon * ring_mask * glow_intensity;
	final_rgb += neon * (shimmer + shimmer2) * glow_intensity;

	float final_alpha = clamp(glow_mask + ring_mask + shimmer * 0.4 + shimmer2 * 0.2, 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
