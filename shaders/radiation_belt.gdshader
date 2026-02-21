shader_type canvas_item;

// Radiation belt boundary - synthwave grid with pink/cyan glow.
// Renders as a ring around the arena edge with animated effects.

// Arena parameters (passed from script)
uniform float arena_radius : hint_range(1000.0, 50000.0) = 16000.0;
uniform float belt_width : hint_range(100.0, 2000.0) = 800.0;
uniform vec2 camera_world_pos = vec2(0.0, 0.0);
uniform vec2 rect_size = vec2(4096.0, 4096.0);

// Visual parameters
uniform vec4 color_pink : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform vec4 color_cyan : source_color = vec4(0.0, 1.0, 0.9, 1.0);
uniform float grid_scale : hint_range(10.0, 500.0) = 100.0;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	// Calculate world position of this pixel
	// UV goes 0-1 across the rect, rect is centered on player
	// So UV 0.5 = player position = camera_world_pos
	vec2 offset_from_player = (UV - vec2(0.5)) * rect_size;
	vec2 world_pos = camera_world_pos + offset_from_player;
	float dist_from_center = length(world_pos);
	
	// Calculate belt zone - belt is at the OUTER edge of the arena
	float inner_edge = arena_radius - belt_width;
	float outer_edge = arena_radius;
	
	// Check if we're in the belt zone
	float in_belt = smoothstep(inner_edge - 50.0, inner_edge, dist_from_center) * 
	                (1.0 - smoothstep(outer_edge, outer_edge + 50.0, dist_from_center));
	
	// If not in belt zone, output fully transparent
	if (in_belt < 0.001) {
		COLOR = vec4(0.0);
		return;
	}
	
	// Intensity increases toward outer edge (0 at inner, 1 at outer)
	float belt_t = clamp((dist_from_center - inner_edge) / belt_width, 0.0, 1.0);
	
	// Grid pattern
	vec2 grid_uv = world_pos / grid_scale;
	float grid_x = abs(fract(grid_uv.x) - 0.5) * 2.0;
	float grid_y = abs(fract(grid_uv.y) - 0.5) * 2.0;
	float grid_line = max(
		smoothstep(0.9, 1.0, grid_x),
		smoothstep(0.9, 1.0, grid_y)
	);
	
	// Radial grid lines (spokes)
	float angle = atan(world_pos.y, world_pos.x);
	float radial_lines = abs(fract(angle * 8.0 / TAU) - 0.5) * 2.0;
	float radial_grid = smoothstep(0.85, 1.0, radial_lines);
	
	// Concentric rings
	float ring_freq = dist_from_center / (belt_width * 0.25);
	float rings = abs(fract(ring_freq) - 0.5) * 2.0;
	float ring_lines = smoothstep(0.85, 1.0, rings);
	
	// Combine grid patterns
	float combined_grid = max(max(grid_line, radial_grid * 0.5), ring_lines * 0.7);
	
	// Animated pulse
	float pulse = sin(TIME * pulse_speed + dist_from_center * 0.005) * 0.5 + 0.5;
	float pulse2 = sin(TIME * pulse_speed * 0.7 - angle * 3.0) * 0.5 + 0.5;
	
	// Color blend: pink at outer edge, cyan at inner
	vec4 base_color = mix(color_cyan, color_pink, belt_t);
	
	// Add grid glow
	vec4 grid_color = mix(color_cyan, color_pink, pulse2);
	vec4 final_color = mix(base_color * 0.3, grid_color * glow_intensity, combined_grid);
	
	// Intensity ramp: transparent at inner edge, fully visible at outer
	float alpha = belt_t * belt_t; // Quadratic ramp for softer transition
	alpha *= (0.5 + pulse * 0.5); // Pulse modulation
	
	// Edge fade at outer boundary (in_belt already calculated above)
	float outer_fade = 1.0 - smoothstep(outer_edge - 50.0, outer_edge + 50.0, dist_from_center);
	
	final_color.a = alpha * in_belt * outer_fade;
	
	// Boost RGB for HDR glow
	final_color.rgb *= glow_intensity;
	
	COLOR = final_color;
}
