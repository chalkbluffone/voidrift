shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.06;
uniform float scanline_speed : hint_range(0.0, 30.0) = 5.0;
uniform float scanline_count : hint_range(50.0, 500.0) = 200.0;
uniform float chromatic_offset : hint_range(0.0, 0.01) = 0.0015;
uniform float glow_amplitude : hint_range(0.0, 0.5) = 0.12;
uniform float glow_speed : hint_range(0.0, 5.0) = 1.5;
uniform float bob_x : hint_range(0.0, 10.0) = 2.0;
uniform float bob_y : hint_range(0.0, 10.0) = 3.0;
uniform float bob_period_x : hint_range(1.0, 20.0) = 5.0;
uniform float bob_period_y : hint_range(1.0, 20.0) = 3.5;

void vertex() {
	VERTEX.x += sin(TIME * TAU / bob_period_x) * bob_x;
	VERTEX.y += sin(TIME * TAU / bob_period_y) * bob_y;
}

void fragment() {
	vec2 uv = UV;

	// Chromatic aberration — offset R and B channels slightly
	float offset = chromatic_offset;
	float r = texture(TEXTURE, uv + vec2(-offset, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv + vec2(offset, 0.0)).b;
	float a = texture(TEXTURE, uv).a;

	vec3 col = vec3(r, g, b);

	// Glow pulse — slow sine-wave brightness modulation
	float pulse = 1.0 + glow_amplitude * sin(TIME * glow_speed * TAU);
	col *= pulse;

	// Scanlines — horizontal lines scrolling upward
	float scanline = sin((uv.y * scanline_count) + TIME * scanline_speed) * 0.5 + 0.5;
	col -= scanline_intensity * scanline;

	COLOR = vec4(col, a);
}
