shader_type canvas_item;

// Circle mask shader - clips content to a circular shape.
// Used by: minimap, fog of war overlay, circular UI elements.

// Mask parameters
uniform float mask_radius : hint_range(0.1, 0.5) = 0.5;
uniform float edge_softness : hint_range(0.001, 0.05) = 0.01;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	
	// Circle mask
	float circle_mask = 1.0 - smoothstep(mask_radius - edge_softness, mask_radius, dist);
	
	// Sample original content (from draw calls or texture)
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Apply mask to alpha
	tex_color.a *= circle_mask;
	
	COLOR = tex_color;
}
