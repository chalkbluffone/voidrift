shader_type canvas_item;
render_mode unshaded, blend_mix;

// Nope Bubble — Plasma Membrane shield shader.
// Renders a living, organic-looking energy membrane with flowing plasma noise,
// electric arc veins (voronoi), and a purple/violet/magenta palette.

uniform vec4 shield_color : source_color = vec4(0.55, 0.15, 0.85, 0.8);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

// Tuning knobs
const float SHIELD_RADIUS = 0.92;
const float SHELL_HALF   = 0.012;  // wider visible ring edge
const float GLOW_WIDTH   = 0.10;   // broad neon bloom
const float ARC_INTENSITY = 0.85;  // bright voronoi veins
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
	float band = smoothstep(inner_edge - 0.006, inner_edge, dist)
	           * smoothstep(outer_edge + 0.006, outer_edge, dist);

	// Outer glow (neon bloom beyond the shell)
	float glow_d = max(dist - outer_edge, 0.0);
	float outer_glow = exp(-glow_d * glow_d / (GLOW_WIDTH * GLOW_WIDTH)) * 0.7;

	// Inner glow (soft bloom inside the shell)
	float inner_glow_d = max(inner_edge - dist, 0.0);
	float inner_glow = exp(-inner_glow_d * inner_glow_d / (0.06 * 0.06)) * 0.35;

	// ---- Plasma noise ----
	// Use circular coords (cos/sin) instead of raw angle to avoid polar seam
	vec2 circle = vec2(cos(angle), sin(angle));
	vec2 plasma_uv = circle * 3.0 + vec2(dist * 6.0) + vec2(TIME * PLASMA_SPEED, TIME * PLASMA_SPEED * 0.7);
	float plasma = fbm(plasma_uv * 2.5);

	// ---- Electric arc veins (voronoi) ----
	vec2 arc_uv = circle * 3.5 + vec2(dist * 8.0 + TIME * 0.2, -TIME * 0.3);
	float arcs = 1.0 - voronoi(arc_uv * 1.8);
	arcs = pow(arcs, 3.0) * ARC_INTENSITY;  // sharpen into thin veins

	// ---- Color palette derived from shield_color ----
	// Dark spots = dark version of base color, moving energy = lighter tint
	vec3 base = shield_color.rgb;
	vec3 dark_base   = base * 0.2;                              // deep shadow
	vec3 light_tint  = mix(base, vec3(1.0), 0.2);               // subtle lighten
	vec3 bright_core = mix(base, vec3(1.0), 0.35);              // slightly brighter, still colored

	// Blend based on energy (plasma + arcs)
	float energy = clamp(plasma * 0.7 + arcs, 0.0, 1.0);
	vec3 col = mix(dark_base, light_tint, energy);
	col = mix(col, bright_core, smoothstep(0.75, 1.0, energy));

	// ---- Pulse hit flash (additive white overlay) ----
	col = mix(col, vec3(1.0), pulse * 0.85);

	// ---- Combine alphas ----
	float shell_alpha = band * (0.7 + 0.3 * energy) * shield_color.a * opacity;
	float glow_alpha  = (outer_glow + inner_glow) * opacity * shield_color.a * 0.85;
	float final_alpha = max(shell_alpha, glow_alpha);

	// Inner haze — visible energy fill so the bubble feels alive
	float inner_haze = smoothstep(inner_edge, inner_edge - 0.18, dist) * 0.12 * opacity;
	final_alpha = max(final_alpha, inner_haze);

	// ---- Circular mask: force alpha to zero before quad edge to prevent square clipping ----
	final_alpha *= smoothstep(1.0, 0.94, dist);

	if (final_alpha < 0.003) {
		discard;
	}

	// Boost brightness for neon punch, apply 40% transparency
	COLOR = vec4(col * 1.1, final_alpha * 0.6);
}
