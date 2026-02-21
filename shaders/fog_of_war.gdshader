shader_type canvas_item;

// Fog of War Shader - neon purple gas effect over unexplored areas.
// Uses fog texture where black = unexplored, white = explored.

uniform sampler2D fog_texture : filter_nearest, repeat_disable;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.9;
uniform float noise_scale : hint_range(1.0, 100.0) = 15.0;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.4;

// Neon purple/pink synthwave colors
uniform vec4 fog_color_bright : source_color = vec4(0.8, 0.2, 1.0, 1.0);   // Bright magenta
uniform vec4 fog_color_glow : source_color = vec4(0.5, 0.0, 0.8, 1.0);      // Deep purple
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;

// Circle mask parameters
uniform float mask_radius : hint_range(0.1, 0.5) = 0.5;
uniform float edge_softness : hint_range(0.001, 0.05) = 0.02;

// Simple pseudo-noise function for fog wisps
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// Sample the fog texture (black = unexplored, white = explored)
	float explored = texture(fog_texture, UV).r;
	
	// Calculate fog visibility (invert: 1 = show fog, 0 = clear)
	float fog_visibility = 1.0 - explored;
	
	// Apply soft edge transition
	fog_visibility = smoothstep(0.0, 0.4, fog_visibility);
	
	// Add animated noise for gas/plasma effect
	vec2 noise_uv = UV * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed * 0.6);
	float gas_noise = fbm(noise_uv);
	
	// Secondary noise layer for more organic movement
	vec2 noise_uv2 = UV * noise_scale * 0.7 - vec2(TIME * noise_speed * 0.8, TIME * noise_speed * 0.5);
	float gas_noise2 = fbm(noise_uv2);
	
	// Combine noise layers
	float combined_noise = (gas_noise + gas_noise2) * 0.5;
	
	// Pulsing glow effect
	float pulse = sin(TIME * 2.0 + combined_noise * 4.0) * 0.15 + 0.85;
	
	// Mix neon colors based on noise for plasma effect
	vec4 fog_color = mix(fog_color_glow, fog_color_bright, combined_noise * pulse);
	
	// Add bright edges where fog meets explored areas (neon glow at boundaries)
	float edge_glow = smoothstep(0.3, 0.6, fog_visibility) * (1.0 - smoothstep(0.6, 0.9, fog_visibility));
	fog_color.rgb += edge_glow * fog_color_bright.rgb * 0.5;
	
	// Apply glow intensity
	fog_color.rgb *= glow_intensity;
	
	// Modulate visibility with noise for wispy gas effect
	float final_visibility = fog_visibility * (0.6 + combined_noise * 0.4);
	
	// Apply circular mask to clip fog to map bounds
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float circle_mask = 1.0 - smoothstep(mask_radius - edge_softness, mask_radius, dist);
	
	// Output neon fog color with circle mask
	COLOR = vec4(fog_color.rgb, final_visibility * fog_opacity * circle_mask);
}
