shader_type canvas_item;
render_mode blend_mix;

// Circular spreading fire puddle — procedural flames with noise turbulence
// Consistent with codebase noise functions (hash/noise from radiant_arc)

uniform vec4 color_core : source_color = vec4(1.0, 0.95, 0.5, 1.0);  // Bright yellow-white center
uniform vec4 color_mid : source_color = vec4(1.0, 0.45, 0.05, 1.0);  // Orange flames
uniform vec4 color_outer : source_color = vec4(0.6, 0.08, 0.0, 1.0); // Deep red edge
uniform vec4 color_smoke : source_color = vec4(0.15, 0.1, 0.08, 0.6); // Dark smoke tips
uniform float glow_strength : hint_range(0.5, 10.0) = 4.5;
uniform float flame_speed : hint_range(0.5, 8.0) = 3.0;
uniform float flame_turbulence : hint_range(0.0, 1.0) = 0.6;
uniform float seed_offset = 0.0;
uniform float alpha = 1.0;
uniform float progress = 0.0;        // Driven by GDScript elapsed time
uniform float radius_progress = 1.0; // 0→1 controls visible spread radius
uniform float burn_intensity = 1.0;  // 1→0 for burnout fade

// Noise functions (consistent with radiant_arc.gdshader)
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
	return mix(mix(n0, n1, f.x), mix(n2, n3, f.x), f.y);
}

// Multi-octave noise for flame turbulence
float fire_noise(vec2 p, float time) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	// Scroll upward to simulate heat rise
	vec2 scroll = vec2(0.0, -time * flame_speed);
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p * freq + scroll * freq * 0.4);
		freq *= 2.2;
		amp *= 0.45;
	}
	return val;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float time = progress;

	// Radial position normalized to 0-1 within the circle
	float radial = dist * 2.0;  // 0 at center, 1 at edge of UV

	// Apply spreading radius — pixels beyond current radius are invisible
	float visible = smoothstep(radius_progress, radius_progress * 0.85, radial);

	// Fire turbulence: distort radial distance for flickering flame edges
	float angle = atan(centered.y, centered.x);
	float turb = fire_noise(vec2(angle * 1.5, radial * 3.0), time);
	float turb2 = fire_noise(vec2(angle * 3.0 + 10.0, radial * 5.0), time * 1.3);

	// Distort the radial distance for organic flame shapes
	float distorted_radial = radial + (turb - 0.5) * flame_turbulence * 0.4;
	distorted_radial += (turb2 - 0.5) * flame_turbulence * 0.15;

	// Edge flickering — more noise at the outer edge for dancing flames
	float edge_flicker = fire_noise(vec2(angle * 5.0, time * 6.0), time * 0.7);
	float edge_zone = smoothstep(0.5, 1.0, radial / max(radius_progress, 0.01));
	distorted_radial += edge_flicker * edge_zone * flame_turbulence * 0.2;

	// Fire intensity: hot center, cooler edges
	float intensity = 1.0 - smoothstep(0.0, radius_progress * 0.95, distorted_radial);
	intensity = pow(max(intensity, 0.0), 0.55);  // Brighter, wider hot center

	// Inner bloom: extra glow right at the center
	float bloom = exp(-distorted_radial * distorted_radial * 8.0) * 0.35;
	intensity = min(intensity + bloom, 1.0);

	// Color gradient: core -> mid -> outer -> smoke tips at the very edge
	float core_zone = smoothstep(0.35, 0.0, distorted_radial);
	float mid_zone = smoothstep(0.65, 0.1, distorted_radial);
	float smoke_zone = smoothstep(0.6, 1.0, distorted_radial / max(radius_progress, 0.01));

	vec3 fire_color = mix(color_outer.rgb, color_mid.rgb, mid_zone);
	fire_color = mix(fire_color, color_core.rgb, core_zone);
	fire_color = mix(fire_color, color_smoke.rgb, smoke_zone * 0.5);

	// Pulsing brightness — layered sin waves for natural flicker
	float flicker1 = sin(time * 8.0 + angle * 3.0) * 0.5 + 0.5;
	float flicker2 = sin(time * 13.0 + angle * 5.0 + 1.0) * 0.5 + 0.5;
	float flicker = 0.85 + 0.15 * (flicker1 * 0.6 + flicker2 * 0.4);
	fire_color *= flicker;

	// Hot spots — random bright patches that appear and disappear
	float hotspot = noise(vec2(angle * 2.0 + time * 2.0, radial * 3.0 + seed_offset));
	hotspot = smoothstep(0.65, 0.85, hotspot) * (1.0 - edge_zone);
	fire_color = mix(fire_color, color_core.rgb * 1.3, hotspot * 0.4);

	// Final alpha: shape * intensity * burn state * overall
	float final_alpha = visible * intensity * burn_intensity * alpha * glow_strength * 0.25;
	final_alpha = clamp(final_alpha, 0.0, 1.0);

	COLOR = vec4(fire_color, final_alpha);
}
