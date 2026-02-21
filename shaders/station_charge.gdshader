shader_type canvas_item;

// Station charge progress ring shader
// Draws a radial arc showing charge percentage with neon glow effect

// Progress parameters
uniform float charge : hint_range(0.0, 1.0) = 0.0;

// Ring parameters
uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.0, 0.2) = 0.05;
uniform float glow_size : hint_range(0.0, 0.1) = 0.02;

// Colors (synthwave palette)
uniform vec4 color_empty : source_color = vec4(0.2, 0.2, 0.3, 0.5);
uniform vec4 color_charging : source_color = vec4(0.0, 1.0, 1.0, 1.0);  // Cyan
uniform vec4 color_full : source_color = vec4(1.0, 0.08, 0.58, 1.0);     // Hot Pink
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 0.6);       // Cyan glow

// Animation
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.2;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	
	// Calculate angle (0 at top, clockwise)
	float angle = atan(centered.x, -centered.y);
	float normalized_angle = (angle + PI) / (2.0 * PI);  // 0 to 1
	
	// Ring mask with soft edges
	float inner_edge = radius - thickness * 0.5;
	float outer_edge = radius + thickness * 0.5;
	
	float ring_mask = smoothstep(inner_edge - glow_size, inner_edge, dist);
	ring_mask *= 1.0 - smoothstep(outer_edge, outer_edge + glow_size, dist);
	
	// Progress arc mask
	float progress_mask = step(normalized_angle, charge);
	
	// Glow effect for outer edge
	float glow_mask = smoothstep(outer_edge + glow_size, outer_edge, dist);
	glow_mask *= 1.0 - smoothstep(inner_edge, inner_edge - glow_size, dist);
	glow_mask *= progress_mask;
	
	// Pulse animation when charging
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity * charge;
	
	// Determine colors
	vec4 progress_color = mix(color_charging, color_full, charge);
	
	// Combine: empty ring + progress arc + glow
	vec4 empty_ring = color_empty * ring_mask * (1.0 - progress_mask);
	vec4 progress_ring = progress_color * ring_mask * progress_mask * pulse;
	vec4 glow = glow_color * glow_mask * pulse * 0.5;
	
	COLOR = empty_ring + progress_ring + glow;
	
	// Full charge effect - extra bright glow
	if (charge >= 1.0) {
		float full_pulse = 0.5 + 0.5 * sin(TIME * 4.0);
		COLOR.rgb += color_full.rgb * ring_mask * full_pulse * 0.3;
	}
}
