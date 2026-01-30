shader_type canvas_item;
render_mode blend_mix;

// Colors and glow
uniform vec4 color_a : source_color = vec4(0.0, 1.0, 1.0, 1.0);  // Cyan
uniform vec4 color_b : source_color = vec4(1.0, 0.0, 1.0, 1.0);  // Magenta
uniform vec4 color_c : source_color = vec4(1.0, 0.4, 0.8, 1.0);  // Pink
uniform float glow_strength = 3.5;
uniform float core_strength = 0.8;
uniform float noise_strength = 0.3;
uniform float uv_scroll_speed = 2.0;

// Animation
uniform float progress = 0.0;  // 0 to 1 over lifetime
uniform float alpha = 1.0;     // Master alpha fade
uniform float sweep_progress = 1.0;  // Arc sweep from 0 to 1
uniform float seed_offset = 0.0;

// Simple noise function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

void fragment() {
	// UV.x = Progress along arc (0..1) - 0 is starting tip, 1 is ending tip
	// UV.y = Thickness (0=outer, 1=inner)
	
	// Create a "beam" profile across the V axis (Thickness)
	// Peak at 0.5 (center of thickness), fade to 0 at edges
	float beam_profile = 1.0 - abs(UV.y - 0.5) * 2.0;
	beam_profile = pow(beam_profile, 1.5); // Smooth rounding
	
	// COUNTER-CLOCKWISE SWEEP ANIMATION
	float sweep_edge = sweep_progress * 1.8; // Extended range for full tail exit
	
	// Distance from current pixel to the leading edge
	float dist_from_edge = sweep_edge - UV.x;
	
	// WISPY TAIL: Gradual fade from leading edge back
	float tail_length = 0.5;
	float tail_fade = 1.0 - smoothstep(0.0, tail_length, dist_from_edge);
	tail_fade = pow(tail_fade, 0.7); // Softer falloff for wispy look
	
	// WISPY TIP: Fade the leading edge to transparency as it reaches the end
	float tip_wisp = smoothstep(1.0, 0.5, UV.x); // Start fading at 50%
	tip_wisp = pow(tip_wisp, 1.5); // Accelerate the fade
	
	// Leading edge glow
	float leading_edge = smoothstep(0.2, 0.0, dist_from_edge) * smoothstep(-0.05, 0.03, dist_from_edge);
	leading_edge *= tip_wisp;
	
	// Soft reveal (no hard edge)
	float revealed = smoothstep(-0.02, 0.08, dist_from_edge);
	
	// Color Gradient along the arc
	vec3 base_color = mix(color_a.rgb, color_b.rgb, UV.x);
	
	// Slight brightness boost at leading edge
	base_color = mix(base_color, vec3(1.0), leading_edge * 0.3);
	
	// Define the core (bright center line) - also fades at tip
	float core = smoothstep(0.75, 1.0, beam_profile) * tip_wisp;
	
	// Define the main glow body
	float body = smoothstep(0.1, 0.7, beam_profile);
	
	// Combine: body fades with tail, tip fades with wisp
	float visibility = body * revealed * tail_fade * tip_wisp;
	// Add leading edge glow
	visibility += leading_edge * body * 0.8;
	// Add subtle core
	visibility += core * 0.3 * tail_fade;
	
	// Final alpha - wisps should be more transparent overall
	float final_alpha = visibility * alpha * glow_strength * 0.4;
	final_alpha = clamp(final_alpha, 0.0, 1.0);
	
	COLOR = vec4(base_color, final_alpha);
}
