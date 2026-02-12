shader_type canvas_item;
render_mode unshaded, blend_mix;

// Nope Bubble — Plasma Membrane shield shader.
// Renders a living, organic-looking energy membrane with flowing plasma noise,
// electric arc veins (voronoi), and a purple/violet/magenta palette.

uniform vec4 shield_color : source_color = vec4(0.55, 0.15, 0.85, 0.8);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

// Tuning knobs
const float SHIELD_RADIUS = 0.40;
const float SHELL_HALF   = 0.052;  // membrane thickness (half-width)
const float GLOW_WIDTH   = 0.09;   // soft outer bloom
const float ARC_INTENSITY = 0.45;  // voronoi vein brightness
const float PLASMA_SPEED  = 0.35;  // flow speed of noise

// ---- Hash helpers ----
vec2 hash22(vec2 p) {
	vec3 a = fract(p.xyx * vec3(443.897, 441.423, 437.195));
	a += dot(a, a.yzx + 19.19);
	return fract((a.xx + a.yz) * a.zy);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ---- Value noise (smooth) ----
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep interp
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ---- FBM (3 octaves) ----
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return v;
}

// ---- Voronoi distance (for electric arcs) ----
float voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash22(i + neighbor);
			// Animate cell centres slowly
			point = 0.5 + 0.5 * sin(TIME * 0.8 + 6.2831 * point);
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

// ---- Main ----
void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);

	// ---- Shell band mask (ring, not filled disc) ----
	float inner_edge = SHIELD_RADIUS - SHELL_HALF;
	float outer_edge = SHIELD_RADIUS + SHELL_HALF;
	float band = smoothstep(inner_edge - 0.04, inner_edge + 0.02, dist)
	           * smoothstep(outer_edge + 0.04, outer_edge - 0.02, dist);

	// Outer glow (soft bloom beyond the shell)
	float glow_d = max(dist - outer_edge, 0.0);
	float outer_glow = exp(-glow_d * glow_d / (GLOW_WIDTH * GLOW_WIDTH)) * 0.55;

	// ---- Plasma noise ----
	// Use circular coords (cos/sin) instead of raw angle to avoid polar seam
	vec2 circle = vec2(cos(angle), sin(angle));
	vec2 plasma_uv = circle * 3.0 + vec2(dist * 6.0) + vec2(TIME * PLASMA_SPEED, TIME * PLASMA_SPEED * 0.7);
	float plasma = fbm(plasma_uv * 2.5);

	// ---- Electric arc veins (voronoi) ----
	vec2 arc_uv = circle * 3.5 + vec2(dist * 8.0 + TIME * 0.2, -TIME * 0.3);
	float arcs = 1.0 - voronoi(arc_uv * 1.8);
	arcs = pow(arcs, 3.0) * ARC_INTENSITY;  // sharpen into thin veins

	// ---- Color palette: deep purple → magenta → white-hot ----
	vec3 deep_purple = vec3(0.25, 0.05, 0.45);
	vec3 magenta     = vec3(0.85, 0.15, 0.65);
	vec3 white_hot   = vec3(1.0, 0.9, 1.0);

	// Blend based on energy (plasma + arcs)
	float energy = clamp(plasma * 0.7 + arcs, 0.0, 1.0);
	vec3 col = mix(deep_purple, magenta, energy);
	col = mix(col, white_hot, smoothstep(0.7, 1.0, energy));

	// Tint toward the uniform colour subtly
	col = mix(col, shield_color.rgb, 0.2);

	// ---- Pulse hit flash (additive white overlay) ----
	col = mix(col, vec3(1.0), pulse * 0.85);

	// ---- Combine alphas ----
	float shell_alpha = band * (0.6 + 0.4 * energy) * shield_color.a * opacity;
	float glow_alpha  = outer_glow * opacity * shield_color.a * 0.6;
	float final_alpha = max(shell_alpha, glow_alpha);

	// Also add a faint inner haze (very transparent) so small shields don't look empty
	float inner_haze = smoothstep(inner_edge, inner_edge - 0.13, dist) * 0.08 * opacity;
	final_alpha = max(final_alpha, inner_haze);

	if (final_alpha < 0.005) {
		discard;
	}

	COLOR = vec4(col, final_alpha);
}
