shader_type canvas_item;

// Freighter underglow — soft radial glow beneath the ship with subtle pulse.
// Tint via glow_color uniform to match freighter type (blue for XP, yellow for credits).

// Color parameters
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 0.6);
uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;

// Shape
uniform float falloff : hint_range(0.5, 4.0) = 2.0;

// Animation
uniform float pulse_speed : hint_range(0.5, 5.0) = 1.5;
uniform float pulse_min : hint_range(0.2, 1.0) = 0.5;
uniform float pulse_max : hint_range(0.8, 1.5) = 1.0;


void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;  // 0 at center, 1 at edge

	// Radial falloff
	float glow = 1.0 - pow(clamp(dist, 0.0, 1.0), falloff);

	// Pulse animation
	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));

	// Combine
	float alpha = glow * pulse * glow_color.a;
	vec3 color = glow_color.rgb * glow_intensity;

	COLOR = vec4(color, alpha);
}
