shader_type canvas_item;
render_mode blend_mix;

// Colors and glow
uniform vec4 color_a : source_color = vec4(0.0, 1.0, 1.0, 1.0);  // Cyan (0-33%)
uniform vec4 color_b : source_color = vec4(1.0, 0.0, 1.0, 1.0);  // Magenta (33-66%)
uniform vec4 color_c : source_color = vec4(1.0, 0.4, 0.8, 1.0);  // Pink (66-100%)
uniform float glow_strength = 3.5;
uniform float core_strength = 0.8;  // Controls bright center line intensity
uniform float noise_strength = 0.3;  // Edge distortion amount
uniform float uv_scroll_speed = 2.0;

// Animation
uniform float progress = 0.0;  // 0 to 1 over lifetime
uniform float alpha = 1.0;     // Master alpha fade
uniform float sweep_progress = 1.0;  // Arc sweep from 0 to 1
uniform float seed_offset = 0.0;  // Randomizes noise pattern per arc instance

// Chromatic Aberration
uniform float chromatic_aberration = 0.0;  // 0 = off, 0.5 = subtle, 1.0+ = intense

// Pulsing/Flickering
uniform float pulse_strength = 0.0;  // 0 = off, 0.5 = subtle, 1.0 = intense
uniform float pulse_speed = 8.0;  // Pulses per second

// Electric Arcs
uniform float electric_strength = 0.0;  // 0 = off, 0.5 = subtle, 1.0 = intense
uniform float electric_frequency = 20.0;  // Higher = finer detail
uniform float electric_speed = 15.0;  // Animation speed

// Gradient Control
uniform float gradient_offset = 0.0;  // Rotates gradient around arc (-1 to 1)

// Boomerang: when > 0.5, bypass sweep fade and show the full arc
uniform float full_visible = 0.0;

// Simple noise function
float hash(vec2 p) {
	return fract(sin(dot(p + vec2(seed_offset), vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float n0 = hash(i);
	float n1 = hash(i + vec2(1.0, 0.0));
	float n2 = hash(i + vec2(0.0, 1.0));
	float n3 = hash(i + vec2(1.0, 1.0));
	
	float nx0 = mix(n0, n1, f.x);
	float nx1 = mix(n2, n3, f.x);
	return mix(nx0, nx1, f.y);
}

// High-frequency noise for electric arcs
float electric_noise(vec2 p, float time) {
	float n1 = noise(p * electric_frequency + vec2(time * electric_speed, 0.0));
	float n2 = noise(p * electric_frequency * 2.3 + vec2(0.0, time * electric_speed * 1.7));
	float n3 = noise(p * electric_frequency * 4.1 + vec2(time * electric_speed * 0.8, time * electric_speed));
	float combined = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
	return pow(combined, 0.5) * 2.0 - 0.5;
}

// 3-color gradient with adjusted distribution to compensate for taper/fade
// Color A gets more UV space (tail fades), Color C gets more (tip tapers)
vec3 get_gradient_color(float t) {
	// Apply gradient offset to rotate colors around arc
	float u = t + gradient_offset;
	u = u - floor(u);  // Manual fract for wrapping
	
	// Adjusted bands: A=0-50%, B=50-80%, C=80-100%
	if (u < 0.50) {
		// Color A to Color B transition
		float local_t = u / 0.50;
		return mix(color_a.rgb, color_b.rgb, local_t);
	} else if (u < 0.80) {
		// Color B to Color C transition  
		float local_t = (u - 0.50) / 0.30;
		return mix(color_b.rgb, color_c.rgb, local_t);
	} else {
		// Color C
		return color_c.rgb;
	}
}

void fragment() {
	float time = progress;
	
	// Apply noise distortion to UV for organic edge
	float noise_val = noise(UV * 8.0 + vec2(time * uv_scroll_speed, 0.0));
	vec2 distorted_uv = UV;
	distorted_uv.y += (noise_val - 0.5) * noise_strength * 0.2;
	
	// Apply electric noise for jagged edges
	if (electric_strength > 0.0) {
		float electric = electric_noise(UV, time);
		distorted_uv.y += electric * electric_strength * 0.15;
	}
	
	// CHROMATIC ABERRATION: Calculate separate beam profiles for R, G, B
	float aberration_offset = chromatic_aberration * 0.08;
	
	// Offset UVs for each color channel
	vec2 uv_r = distorted_uv + vec2(-aberration_offset, -aberration_offset * 0.5);
	vec2 uv_g = distorted_uv;
	vec2 uv_b = distorted_uv + vec2(aberration_offset, aberration_offset * 0.5);
	
	// Create beam profiles for each channel
	float beam_r = 1.0 - abs(uv_r.y - 0.5) * 2.0;
	beam_r = pow(max(beam_r, 0.0), 1.5);
	
	float beam_g = 1.0 - abs(uv_g.y - 0.5) * 2.0;
	beam_g = pow(max(beam_g, 0.0), 1.5);
	
	float beam_b = 1.0 - abs(uv_b.y - 0.5) * 2.0;
	beam_b = pow(max(beam_b, 0.0), 1.5);
	
	// Use center beam for main calculations
	float beam_profile = beam_g;
	
	// COUNTER-CLOCKWISE SWEEP ANIMATION
	float sweep_edge = sweep_progress * 1.8;
	float dist_from_edge = sweep_edge - UV.x;
	
	// WISPY TAIL
	float tail_length = 0.5;
	float tail_fade = 1.0 - smoothstep(0.0, tail_length, dist_from_edge);
	tail_fade = pow(tail_fade, 0.7);
	
	// WISPY TIP
	float tip_wisp = smoothstep(1.0, 0.5, UV.x);
	tip_wisp = pow(tip_wisp, 1.5);
	
	// Leading edge glow
	float leading_edge = smoothstep(0.2, 0.0, dist_from_edge) * smoothstep(-0.05, 0.03, dist_from_edge);
	leading_edge *= tip_wisp;
	
	// Soft reveal
	float revealed = smoothstep(-0.02, 0.08, dist_from_edge);
	
	// BOOMERANG OVERRIDE: when full_visible is set, show the entire arc
	if (full_visible > 0.5) {
		tail_fade = 1.0;
		revealed = 1.0;
		leading_edge = 0.0;
	}
	
	// PULSING: Modulate intensity over time
	float pulse = 1.0;
	if (pulse_strength > 0.0) {
		float p1 = sin(time * pulse_speed * 6.28318) * 0.5 + 0.5;
		float p2 = sin(time * pulse_speed * 6.28318 * 1.7 + 1.0) * 0.5 + 0.5;
		float p3 = sin(time * pulse_speed * 6.28318 * 0.5 + 2.0) * 0.5 + 0.5;
		float pulse_value = p1 * 0.5 + p2 * 0.3 + p3 * 0.2;
		pulse = mix(1.0 - pulse_strength * 0.4, 1.0 + pulse_strength * 0.3, pulse_value);
	}
	
	// Get base gradient color
	vec3 base_color = get_gradient_color(UV.x);
	
	// ELECTRIC ARCS: Add bright electric highlights
	if (electric_strength > 0.0) {
		float electric = electric_noise(UV, time);
		float electric_highlight = smoothstep(0.3, 0.8, electric) * electric_strength;
		base_color = mix(base_color, vec3(1.0, 1.0, 0.9), electric_highlight * 0.5 * beam_profile);
	}
	
	// Brightness boost at leading edge
	base_color = mix(base_color, vec3(1.0), leading_edge * 0.3);
	
	// Core line
	float core = smoothstep(0.75, 1.0, beam_profile) * tip_wisp * core_strength;
	
	// Main glow body - calculate for each channel separately for chromatic aberration
	float body_r = smoothstep(0.1, 0.7, beam_r);
	float body_g = smoothstep(0.1, 0.7, beam_g);
	float body_b = smoothstep(0.1, 0.7, beam_b);
	float body = smoothstep(0.1, 0.7, beam_profile);
	
	// Combine visibility for each channel
	float vis_base = revealed * tail_fade * tip_wisp;
	float vis_r = body_r * vis_base + leading_edge * body_r * 0.8 + core * 0.3 * tail_fade;
	float vis_g = body_g * vis_base + leading_edge * body_g * 0.8 + core * 0.3 * tail_fade;
	float vis_b = body_b * vis_base + leading_edge * body_b * 0.8 + core * 0.3 * tail_fade;
	float visibility = body * vis_base + leading_edge * body * 0.8 + core * 0.3 * tail_fade;
	
	// Apply pulsing
	vis_r *= pulse;
	vis_g *= pulse;
	vis_b *= pulse;
	visibility *= pulse;
	
	// CHROMATIC ABERRATION: Use separate visibilities per channel
	vec3 final_color;
	float final_alpha;
	if (chromatic_aberration > 0.0) {
		// Each channel gets its own visibility, creating color fringing at edges
		float alpha_r = vis_r * alpha * glow_strength * 0.4;
		float alpha_g = vis_g * alpha * glow_strength * 0.4;
		float alpha_b = vis_b * alpha * glow_strength * 0.4;
		
		final_color = vec3(
			base_color.r * clamp(alpha_r, 0.0, 1.0),
			base_color.g * clamp(alpha_g, 0.0, 1.0),
			base_color.b * clamp(alpha_b, 0.0, 1.0)
		);
		final_alpha = max(max(alpha_r, alpha_g), alpha_b);
		final_alpha = clamp(final_alpha, 0.0, 1.0);
		
		// Normalize color by alpha to prevent darkening
		if (final_alpha > 0.01) {
			final_color /= final_alpha;
		}
	} else {
		final_alpha = visibility * alpha * glow_strength * 0.4;
		final_alpha = clamp(final_alpha, 0.0, 1.0);
		final_color = base_color;
	}
	
	COLOR = vec4(final_color, final_alpha);
}
