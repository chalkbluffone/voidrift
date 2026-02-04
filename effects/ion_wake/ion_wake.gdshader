shader_type canvas_item;
render_mode blend_mix;

// Ion Wake - Planar Shockwave Ring Shader
// A clean expanding ring with gradient coloring and soft edges

// Colors
uniform vec4 color_inner : source_color = vec4(0.4, 0.8, 1.0, 1.0);  // Inner/trailing color
uniform vec4 color_outer : source_color = vec4(0.1, 0.3, 0.8, 1.0);  // Outer color
uniform vec4 color_edge : source_color = vec4(0.9, 0.95, 1.0, 1.0);  // Leading edge highlight

// Ring appearance
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;  // Overall brightness boost
uniform float edge_sharpness : hint_range(0.1, 5.0) = 2.0;  // How sharp/soft the ring edges are
uniform float edge_glow : hint_range(0.0, 3.0) = 1.0;  // Bright leading edge intensity

// Animation state (set by GDScript)
uniform float alpha : hint_range(0.0, 1.0) = 1.0;  // Master fade

// UV Layout:
// U (x): 0 = leading edge (outer), 1 = trailing edge (inner)
// V (y): 0-1 wrapping around the ring circumference

void fragment() {
	float dist_from_edge = UV.x;  // 0 at leading edge, 1 at trailing
	
	// Color gradient from edge -> inner -> outer
	vec3 base_color;
	if (dist_from_edge < 0.1) {
		// Leading edge - bright highlight
		float t = dist_from_edge / 0.1;
		base_color = mix(color_edge.rgb, color_inner.rgb, t);
	} else if (dist_from_edge < 0.5) {
		// Front half - inner color
		float t = (dist_from_edge - 0.1) / 0.4;
		base_color = mix(color_inner.rgb, color_outer.rgb, t * 0.5);
	} else {
		// Back half - fade to outer
		float t = (dist_from_edge - 0.5) / 0.5;
		base_color = mix(mix(color_inner.rgb, color_outer.rgb, 0.5), color_outer.rgb, t);
	}
	
	// Leading edge glow
	float leading_glow = exp(-dist_from_edge * 10.0) * edge_glow;
	base_color += color_edge.rgb * leading_glow;
	
	// Apply overall glow
	base_color *= (1.0 + glow_strength * 0.3);
	
	// Soft fade at trailing edge
	float trail_alpha = 1.0 - smoothstep(0.5, 1.0, dist_from_edge);
	
	// Soft fade at leading edge (very slight)
	float lead_alpha = smoothstep(0.0, 0.05, dist_from_edge) * 0.3 + 0.7;
	
	float final_alpha = trail_alpha * lead_alpha * alpha;
	
	COLOR = vec4(base_color, final_alpha);
}
