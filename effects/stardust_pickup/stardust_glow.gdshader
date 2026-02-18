shader_type canvas_item;

// Stardust pickup — four-pointed star (✦) cycling through OutRun synthwave neon palette.
// Smoothly transitions between neon colors with glow and sparkle.

// Animation
uniform float color_cycle_speed : hint_range(0.2, 4.0) = 0.8;
uniform float glow_intensity : hint_range(0.5, 3.0) = 2.0;

// Shape parameters
uniform float star_sharpness : hint_range(1.0, 8.0) = 1.5;
uniform float rotation_speed : hint_range(0.0, 4.0) = 0.8;

// Pulse parameters
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.5;
uniform float pulse_min : hint_range(0.3, 1.0) = 0.6;
uniform float pulse_max : hint_range(1.0, 2.0) = 1.2;

// Sparkle parameters
uniform float sparkle_speed : hint_range(1.0, 10.0) = 5.0;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.4;


// OutRun synthwave neon palette — 10 key colors
const int COLOR_COUNT = 10;
vec3 get_palette_color(int idx) {
	// FF6C11 orange, FF3864 hot pink, 2DE2E6 cyan, F9C80E yellow,
	// FD3777 magenta, F706CF neon pink, FD1D53 red-pink,
	// 650D89 purple, 920075 deep magenta, 791E94 violet
	if (idx == 0) return vec3(1.0, 0.424, 0.067);      // #FF6C11
	if (idx == 1) return vec3(1.0, 0.220, 0.392);      // #FF3864
	if (idx == 2) return vec3(0.176, 0.886, 0.902);    // #2DE2E6
	if (idx == 3) return vec3(0.976, 0.784, 0.055);    // #F9C80E
	if (idx == 4) return vec3(0.992, 0.216, 0.467);    // #FD3777
	if (idx == 5) return vec3(0.969, 0.024, 0.812);    // #F706CF
	if (idx == 6) return vec3(0.992, 0.114, 0.325);    // #FD1D53
	if (idx == 7) return vec3(0.965, 0.004, 0.616);    // #F6019D
	if (idx == 8) return vec3(0.831, 0.0, 0.471);      // #D40078
	if (idx == 9) return vec3(0.475, 0.118, 0.580);    // #791E94
	return vec3(1.0, 0.424, 0.067);
}


/// Smoothly interpolate between palette colors over time.
vec3 cycle_color(float t) {
	float index_f = t * float(COLOR_COUNT);
	int idx_a = int(mod(floor(index_f), float(COLOR_COUNT)));
	int idx_b = int(mod(floor(index_f) + 1.0, float(COLOR_COUNT)));
	float frac_t = fract(index_f);
	// Smooth interpolation
	float smooth_t = frac_t * frac_t * (3.0 - 2.0 * frac_t);
	return mix(get_palette_color(idx_a), get_palette_color(idx_b), smooth_t);
}


/// Four-pointed star shape SDF.
float star4(vec2 uv, float sharpness) {
	float d1 = abs(uv.x) + abs(uv.y);  // diamond
	float d2 = max(abs(uv.x), abs(uv.y));  // square
	return mix(d2, d1, 0.5) * sharpness;
}


/// Pseudo-random hash for sparkle
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


void fragment() {
	vec2 uv = UV - 0.5;

	// Slow rotation
	float angle = TIME * rotation_speed;
	float c = cos(angle);
	float s = sin(angle);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);

	// Four-pointed star distance
	float star_dist = star4(uv, star_sharpness);

	// Pulse animation
	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));

	// Core shape — bright center fading outward
	float core_mask = smoothstep(0.6 * pulse, 0.05, star_dist);

	// Glow halo — softer, wider falloff
	float glow_mask = smoothstep(1.0, 0.1, star_dist) * 0.5;

	// Sparkle — angular shimmer
	float sparkle_angle = atan(uv.y, uv.x);
	float sparkle = pow(abs(sin(sparkle_angle * 4.0 + TIME * sparkle_speed)), 8.0);
	sparkle *= smoothstep(0.8, 0.15, star_dist) * sparkle_intensity;

	// Micro-sparkle
	float micro = hash(floor(uv * 8.0 + TIME * 2.0)) * 0.15;
	micro *= smoothstep(0.6, 0.15, star_dist);

	// Cycle through neon colors
	float cycle_t = fract(TIME * color_cycle_speed);
	vec3 neon = cycle_color(cycle_t);

	// Combine layers with cycling neon color
	vec3 final_rgb = neon * core_mask * glow_intensity;
	final_rgb += neon * glow_mask * glow_intensity * 0.6;
	final_rgb += neon * (sparkle + micro) * glow_intensity;

	// Alpha
	float final_alpha = clamp(core_mask + glow_mask + sparkle * 0.3, 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
