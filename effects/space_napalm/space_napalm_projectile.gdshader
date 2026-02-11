shader_type canvas_item;
render_mode blend_mix;

// Amorphous morphing fire blob with bright comet head and flame tail
// Consistent with codebase noise functions (hash/noise from radiant_arc)

uniform vec4 color_core : source_color = vec4(1.0, 1.0, 0.9, 1.0);   // White-yellow hot center
uniform vec4 color_mid : source_color = vec4(1.0, 0.6, 0.1, 1.0);    // Bright orange
uniform vec4 color_edge : source_color = vec4(0.8, 0.15, 0.0, 1.0);  // Deep red-orange
uniform float glow_strength : hint_range(0.5, 10.0) = 5.0;
uniform float morph_speed : hint_range(0.5, 10.0) = 3.0;
uniform float morph_intensity : hint_range(0.0, 0.5) = 0.25;
uniform float seed_offset = 0.0;
uniform float alpha = 1.0;
uniform float progress = 0.0;  // Driven by GDScript elapsed time
uniform float tail_length : hint_range(0.0, 1.0) = 0.35;

// Noise functions (consistent with radiant_arc.gdshader)
float hash(vec2 p) {
	return fract(sin(dot(p + vec2(seed_offset), vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // Hermite smooth
	float n0 = hash(i);
	float n1 = hash(i + vec2(1.0, 0.0));
	float n2 = hash(i + vec2(0.0, 1.0));
	float n3 = hash(i + vec2(1.0, 1.0));
	return mix(mix(n0, n1, f.x), mix(n2, n3, f.x), f.y);
}

// Multi-octave noise for organic morphing
float fbm(vec2 p, float time) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(p * freq + vec2(time * morph_speed * 0.7, time * morph_speed));
		freq *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	// Center UV so (0.5, 0.5) is the blob center
	vec2 centered = UV - vec2(0.5);
	float time = progress;

	// Stretch horizontally — blob is wider than tall (comet shape)
	// Head is on the right side (+x), tail trails left (-x)
	centered.x *= 0.7;

	// Distance from center (base circular shape)
	float dist = length(centered);

	// Morphing: distort distance with multi-octave noise for amorphous shape
	float angle = atan(centered.y, centered.x);
	float morph = fbm(vec2(angle * 2.0, dist * 4.0), time);
	float distorted_dist = dist + (morph - 0.5) * morph_intensity;

	// Comet tail: elongate the left side (negative x)
	float tail_factor = 1.0;
	if (centered.x < 0.0) {
		// Stretch leftward for tail — the further left, the wider the acceptance
		float tail_stretch = abs(centered.x) * tail_length * 3.0;
		tail_factor = 1.0 / (1.0 + tail_stretch);
		distorted_dist *= tail_factor;
	}

	// Core shape threshold (blob radius ~0.35 of UV space)
	float blob_radius = 0.35;
	float edge = smoothstep(blob_radius, blob_radius * 0.3, distorted_dist);

	// Inner glow structure
	float core_mask = smoothstep(blob_radius * 0.5, 0.0, distorted_dist);
	float mid_mask = smoothstep(blob_radius, blob_radius * 0.15, distorted_dist);

	// Fire color gradient: core -> mid -> edge
	vec3 fire_color = mix(color_edge.rgb, color_mid.rgb, mid_mask);
	fire_color = mix(fire_color, color_core.rgb, core_mask);

	// Center bloom: intense white-hot glow at the very center
	float bloom = exp(-distorted_dist * distorted_dist * 25.0) * 0.5;
	fire_color += vec3(bloom);

	// Add flickering brightness variation
	float flicker = noise(vec2(time * 12.0, seed_offset)) * 0.3 + 0.85;
	float flicker2 = noise(vec2(time * 18.0 + 5.0, seed_offset + 7.0)) * 0.15 + 0.92;
	fire_color *= flicker * flicker2;

	// Tail darkening — tail fades to deeper red/orange
	if (centered.x < 0.0) {
		float tail_dark = smoothstep(0.0, -0.3, centered.x);
		fire_color = mix(fire_color, color_edge.rgb * 0.6, tail_dark * 0.7);
	}

	// Final alpha: blob shape * glow * overall alpha
	float final_alpha = edge * glow_strength * 0.3 * alpha;
	final_alpha = clamp(final_alpha, 0.0, 1.0);

	COLOR = vec4(fire_color, final_alpha);
}
