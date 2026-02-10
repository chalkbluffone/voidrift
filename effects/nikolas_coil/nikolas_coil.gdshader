shader_type canvas_item;
render_mode blend_mix;

// Nikola's Coil — Tesla Chain Lightning Shader
// UV layout: U(x) = 0..1 along bolt length, V(y) = 0..1 across bolt width (center = 0.5)
// Uses TIME for true real-time flicker animation.

// Colors
uniform vec4 color_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_glow : source_color = vec4(0.27, 0.53, 1.0, 1.0);
uniform vec4 color_fringe : source_color = vec4(0.53, 0.27, 0.8, 1.0);

// Appearance
uniform float glow_strength : hint_range(0.5, 8.0) = 4.0;
uniform float bolt_width : hint_range(0.1, 1.0) = 0.5;
uniform float jaggedness : hint_range(0.0, 1.0) = 0.7;
uniform float branch_intensity : hint_range(0.0, 1.0) = 0.3;

// Animation
uniform float elapsed_time : hint_range(0.0, 99.0) = 0.0;  // Real elapsed seconds from GDScript
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float segment_seed : hint_range(0.0, 100.0) = 0.0;
uniform float flicker_speed : hint_range(5.0, 60.0) = 30.0;

// --- Noise ---

float hash(vec2 p) {
	return fract(sin(dot(p + vec2(segment_seed), vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n00 = hash(i);
	float n10 = hash(i + vec2(1.0, 0.0));
	float n01 = hash(i + vec2(0.0, 1.0));
	float n11 = hash(i + vec2(1.0, 1.0));
	return mix(mix(n00, n10, f.x), mix(n01, n11, f.x), f.y);
}

// Multi-octave noise for jagged displacement
float bolt_noise(vec2 p, float t) {
	float n1 = noise(p * 3.0 + vec2(t * 14.0, 0.0));
	float n2 = noise(p * 7.0 + vec2(0.0, t * 20.0));
	float n3 = noise(p * 15.0 + vec2(t * 10.0, t * 16.0));
	float n4 = noise(p * 31.0 + vec2(t * 28.0, 0.0));
	return n1 * 0.4 + n2 * 0.3 + n3 * 0.2 + n4 * 0.1;
}

void fragment() {
	// Use real TIME for flicker so it buzzes continuously,
	// and elapsed_time for slow bolt displacement drift.
	float t_flicker = TIME;
	float t_drift = elapsed_time;

	// === JAGGED BOLT DISPLACEMENT ===
	float displacement = (bolt_noise(UV, t_drift) - 0.5) * 2.0 * jaggedness * 0.15;

	// Clean connections at endpoints
	float endpoint_mask = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	displacement *= endpoint_mask;

	// Distance from displaced center line
	float center = 0.5 + displacement;
	float dist = abs(UV.y - center);

	// === BEAM PROFILE ===
	// Wider zones so glow and fringe are clearly visible
	float core_width = bolt_width * 0.08;
	float core = exp(-pow(dist / max(core_width, 0.001), 2.0) * 6.0);

	float glow_width = bolt_width * 0.22;
	float glow = exp(-pow(dist / max(glow_width, 0.001), 2.0) * 2.0);

	float fringe_width = bolt_width * 0.42;
	float fringe = exp(-pow(dist / max(fringe_width, 0.001), 2.0) * 1.0);

	// === SUB-BRANCHES (shader-level, in addition to GDScript forks) ===
	float branch = 0.0;
	if (branch_intensity > 0.0) {
		// Create thin streaks that look like mini-forks
		// Two layers at different scales for variety
		float n_a = noise(UV * vec2(8.0, 25.0) + vec2(t_flicker * 20.0, segment_seed));
		float n_b = noise(UV * vec2(12.0, 35.0) + vec2(segment_seed, t_flicker * 15.0));

		// Sharp threshold for crisp streaks
		float streak_a = smoothstep(0.72, 0.78, n_a);
		float streak_b = smoothstep(0.72, 0.78, n_b);
		branch = max(streak_a, streak_b);

		// Only near the main bolt, stronger closer to center
		float branch_mask = smoothstep(fringe_width * 1.5, glow_width * 0.5, dist);
		branch *= branch_mask * branch_intensity;
		branch *= endpoint_mask;
	}

	// === ELECTRIC FLICKER (real-time) ===
	float t_f = t_flicker * flicker_speed * 6.28318;
	float f1 = sin(t_f) * 0.5 + 0.5;
	float f2 = sin(t_f * 1.7 + 1.3) * 0.5 + 0.5;
	float f3 = sin(t_f * 3.1 + 2.7) * 0.5 + 0.5;
	// Also use per-position noise for spatial flicker variation
	float spatial_flicker = noise(UV * vec2(6.0, 2.0) + vec2(t_flicker * 40.0, 0.0));
	float flicker = 0.6 + 0.4 * (f1 * 0.4 + f2 * 0.3 + f3 * 0.15 + spatial_flicker * 0.15);

	// === COLOR BLENDING ===
	vec3 bolt_color = color_fringe.rgb * fringe;
	bolt_color = mix(bolt_color, color_glow.rgb, glow);
	bolt_color = mix(bolt_color, color_core.rgb, core);

	// Branch streaks get glow color
	bolt_color += mix(color_glow.rgb, color_core.rgb, 0.4) * branch;

	bolt_color *= (1.0 + glow_strength * 0.2);

	// === ALPHA ===
	float bolt_alpha = max(max(core, glow * 0.7), fringe * 0.3);
	bolt_alpha = max(bolt_alpha, branch * 0.5);
	bolt_alpha *= endpoint_mask;
	bolt_alpha *= flicker * alpha;
	// Mild boost — don't wash out to solid white
	bolt_alpha = clamp(bolt_alpha * (1.0 + glow_strength * 0.15), 0.0, 1.0);

	COLOR = vec4(bolt_color, bolt_alpha);
}
