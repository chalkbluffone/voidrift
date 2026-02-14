shader_type canvas_item;
// Temporarily disable blend_add to debug
// render_mode blend_add;

// ==========================================================================
// RESOLUTION-INDEPENDENT PLANAR SHOCKWAVE
// ==========================================================================
// Works in normalized UV space (0.0-1.0). Center is at vec2(0.5, 0.5).
// The sprite is dynamically scaled by GDScript to match the expanding radius.
// All calculations are resolution-independent.
//
// Heat model: leading edge = core_white (HDR), trailing = fire_orange -> deep_red.
// Erosion: noise_texture eats away at the ring alpha as it expands.
// ==========================================================================

// --- Textures ---
uniform sampler2D fire_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

// --- Expansion state ---
uniform float progress : hint_range(0.0, 1.0) = 0.0;           // 0=spawn, 1=max expansion
uniform float thickness : hint_range(0.01, 0.5) = 0.12;        // Ring width (UV space)
uniform float erosion : hint_range(0.0, 1.0) = 0.0;            // How much noise eats the ring

// --- Heat colors (black-body radiation curve) ---
uniform vec4 core_white : source_color = vec4(2.5, 2.2, 1.8, 1.0);  // HDR white (>1.0 triggers bloom)
uniform vec4 fire_orange : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform vec4 deep_red : source_color = vec4(0.4, 0.05, 0.02, 1.0);

// --- Visual tuning ---
uniform float heat_intensity : hint_range(1.0, 20.0) = 5.0;    // Brightness multiplier
uniform float fire_speed : hint_range(0.0, 5.0) = 1.3;
uniform float fire_scale : hint_range(1.0, 15.0) = 6.0;
uniform float noise_scale : hint_range(1.0, 15.0) = 8.0;
uniform float wake_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float glow_width : hint_range(0.01, 0.2) = 0.06;

// ==========================================================================
// Heat-based color interpolation (black-body radiation)
// h = 0.0 (cold/inner) -> 1.0 (hot/outer leading edge)
// ==========================================================================
vec3 heat_color(float h) {
	if (h < 0.35) {
		// Dark ember to deep red
		return mix(deep_red.rgb * 0.15, deep_red.rgb, h / 0.35);
	} else if (h < 0.6) {
		// Deep red to fire orange
		return mix(deep_red.rgb, fire_orange.rgb, (h - 0.35) / 0.25);
	} else if (h < 0.85) {
		// Orange to yellow-white
		return mix(fire_orange.rgb, core_white.rgb * 0.7, (h - 0.6) / 0.25);
	} else {
		// White-hot core
		return mix(core_white.rgb * 0.7, core_white.rgb, (h - 0.85) / 0.15);
	}
}

void fragment() {
	// Absolute simplest test - just output orange
	COLOR = vec4(1.0, 0.5, 0.0, 1.0);
}
	
	// Early exit when ring hasn't started
	if (progress < 0.001) {
		discard;
	}
	
	// --- Ring geometry (normalized) ---
	// progress drives the outer ring position: 0.0 (center) -> 0.45 (near edge)
	float outer = progress * 0.45;  // Leave margin for glow
	float inner = max(outer - thickness, 0.0);
	
	// --- Polar coordinates for texture sampling ---
	float angle = atan(delta.y, delta.x);
	float ang01 = (angle + 3.14159265) / 6.28318530;
	float t = TIME * fire_speed;
	
	// Fire texture: 2 layers for organic turbulence
	vec2 fuv1 = vec2(ang01 * fire_scale, dist * fire_scale * 0.8) + vec2(t * 0.1, -t * 0.11);
	float f1 = texture(fire_texture, fuv1).r;
	
	vec2 fuv2 = vec2(ang01 * fire_scale * 2.1 + 0.5, dist * fire_scale * 1.2) + vec2(-t * 0.14, t * 0.09);
	float f2 = texture(fire_texture, fuv2).r;
	
	float fire = f1 * 0.6 + f2 * 0.4;
	
	// Noise texture: erosion mask (different scale/scroll for variation)
	vec2 nuv = vec2(ang01 * noise_scale, dist * noise_scale * 0.7) + vec2(t * 0.05, -t * 0.08);
	float noise_val = texture(noise_texture, nuv).r;
	
	// --- Ring mask ---
	// Inner edge: warped by fire noise for jagged flare tendrils
	float inner_warp = (fire - 0.5) * thickness * 0.7;
	float noisy_inner = inner + inner_warp;
	
	// Soft noisy inner, sharp clean outer
	float ring = smoothstep(noisy_inner - 0.01, noisy_inner + 0.006, dist)
	           * (1.0 - smoothstep(outer - 0.003, outer + 0.003, dist));
	
	// --- Heat gradient (position within ring) ---
	float ring_width = max(outer - noisy_inner, 0.001);
	float heat = clamp((dist - noisy_inner) / ring_width, 0.0, 1.0);
	// Fire noise modulates heat for organic variation
	heat += (fire - 0.5) * 0.2;
	heat = clamp(heat, 0.0, 1.0);
	
	// --- Erosion: noise eats away the ring as erosion increases ---
	// Threshold rises with erosion: only bright noise survives
	float erode_threshold = mix(0.05, 0.75, erosion);
	float erode = smoothstep(erode_threshold - 0.12, erode_threshold + 0.08, noise_val);
	ring *= erode;
	
	// --- Density: breakup creates dark crevices (solar flare jaggedness) ---
	float breakup = f1 * f2;  // Multiply creates dark gaps
	float density = smoothstep(0.1, 0.4, breakup);
	// Hot leading edge stays solid, colder regions have more breakup
	ring *= mix(density, 1.0, heat * 0.7);
	
	// --- Inner wake: ember haze inside the ring ---
	float wake = 0.0;
	if (inner > 0.01 && dist < inner) {
		float depth_norm = dist / inner;
		wake = pow(depth_norm, 0.6);  // Stronger near ring edge
		wake *= (fire * 0.3 + 0.7);   // Never fully black
		wake *= wake_intensity;
		wake *= mix(1.0, 0.02, progress);  // Fades as shockwave expands
		wake *= erode;  // Also eroded by noise
	}
	
	// --- Outer glow: colored halo past the sharp outer edge ---
	float glow = 0.0;
	if (dist > outer) {
		float gd = dist - outer;
		glow = exp(-gd * gd / max(glow_width * glow_width * 0.15, 0.00001));
		glow *= smoothstep(0.5, 0.47, dist);  // Fade before UV boundary
	}
	
	// --- COLOR COMPOSITION ---
	// Ring: heat-mapped with HDR white at leading edge
	vec3 ring_col = heat_color(heat) * heat_intensity;
	// Quadratic boost on hot regions for bloom
	ring_col *= 1.0 + heat * heat * 2.5;
	
	// Wake: cool embers
	vec3 wake_col = deep_red.rgb * heat_intensity * 0.2;
	
	// Glow: mid-heat orange
	vec3 glow_col = fire_orange.rgb * heat_intensity * 0.4;
	
	// --- FINAL OUTPUT (additive: black = invisible) ---
	vec3 out_col = ring_col * ring * clamp(fire * 1.3 + 0.1, 0.0, 1.0)
	             + wake_col * wake
	             + glow_col * glow;
	
	// Alpha modulates additive contribution
	float out_a = max(max(ring * 0.9, wake * 0.7), glow * 0.4);
	out_a *= smoothstep(0.5, 0.48, dist);  // Soft circle edge
	
	if (out_a < 0.002) {
		discard;
	}
	
	COLOR = vec4(out_col, clamp(out_a, 0.0, 1.0));
}
