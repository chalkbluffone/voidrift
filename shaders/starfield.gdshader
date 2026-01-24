shader_type canvas_item;

uniform float density = 0.02;
uniform float star_size = 0.025;
uniform float brightness = 0.9;
uniform float twinkle = 0.1;
uniform float layer_scale = 220.0;

uniform int seed = 1;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // NEW

float hash21(vec2 p) {
	p += vec2(float(seed % 4096), float((seed * 1013) % 4096)) * 0.001;

	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 19.19));
}

void fragment() {
	vec2 grid_uv = UV * layer_scale;
	vec2 cell = floor(grid_uv);
	vec2 f = fract(grid_uv);

	float r = hash21(cell);
	float has_star = step(r, density);

	vec2 star_center = hash22(cell + 7.7) * 0.8 + 0.1;

	float size_jitter = mix(0.6, 1.6, hash21(cell + 13.13));
	float radius = star_size * size_jitter;

	float d = distance(f, star_center);

	float core = smoothstep(radius, 0.0, d);
	float glow = smoothstep(radius * 3.0, 0.0, d) * 0.35;

	float tw = 1.0;
	if (twinkle > 0.0) {
		float t = TIME * mix(0.8, 2.2, hash21(cell + 3.3));
		tw = 1.0 + (sin(t + r * 10.0) * 0.5 + 0.5) * twinkle;
	}

	float star = (core + glow) * has_star * brightness * tw;

	// NEW: tint applied here
	vec3 col = tint.rgb;
	COLOR = vec4(col * star, star * tint.a);
}
