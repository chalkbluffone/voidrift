shader_type canvas_item;

uniform vec4 edge_color : source_color = vec4(1.0, 0.08, 0.58, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform vec4 click_color : source_color = vec4(1.0, 0.95, 0.25, 1.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float click_strength : hint_range(0.0, 1.0) = 0.0;
uniform float click_time = -10.0;
uniform float edge_thickness : hint_range(0.001, 0.15) = 0.028;
uniform float corner_radius : hint_range(0.0, 0.35) = 0.08;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.16;

float rounded_rect_mask(vec2 uv, float radius) {
    vec2 d = abs(uv * 2.0 - 1.0);
    vec2 q = d - (1.0 - radius * 2.0);
    float outside = length(max(q, vec2(0.0))) - radius;
    return 1.0 - smoothstep(0.0, 0.004, outside);
}

void fragment() {
    float body_mask = rounded_rect_mask(UV, corner_radius);

    float left = smoothstep(0.0, edge_thickness, UV.x);
    float right = smoothstep(0.0, edge_thickness, 1.0 - UV.x);
    float top = smoothstep(0.0, edge_thickness, UV.y);
    float bottom = smoothstep(0.0, edge_thickness, 1.0 - UV.y);
    float edge = (1.0 - left * right * top * bottom) * body_mask;

    float pulse = 0.5 + 0.5 * sin(TIME * 4.2 + UV.y * 9.0);
    float sweep = smoothstep(0.18, 0.0, abs(UV.x - fract(TIME * 0.24 + 0.2)));
    float scanline = sin((UV.y * 240.0) + TIME * 15.0) * 0.5 + 0.5;
    float elapsed = max(0.0, TIME - click_time);
    float click_decay = exp(-elapsed * 8.5) * click_strength;
    float click_wave = smoothstep(0.22, 0.0, abs(distance(UV, vec2(0.5)) - elapsed * 0.8));
    float click_core = smoothstep(0.22, 0.0, distance(UV, vec2(0.5)));

    vec3 edge_rgb = mix(edge_color.rgb * 0.6, edge_color.rgb * 1.3, pulse);
    vec3 glow_rgb = mix(glow_color.rgb * 0.7, glow_color.rgb * 1.25, sweep);
    vec3 click_rgb = mix(click_color.rgb, vec3(1.0, 0.7, 0.95), pulse);

    float alpha_edge = edge * hover_strength;
    float alpha_glow = edge * sweep * (0.5 + pulse * 0.5) * hover_strength;
    float alpha_scanline = body_mask * scanline_intensity * hover_strength * scanline * 0.25;
    float alpha_click = (click_wave * 0.9 + click_core * 0.35) * click_decay * body_mask;

    vec3 col = edge_rgb * alpha_edge;
    col += glow_rgb * alpha_glow;
    col += vec3(0.2, 0.05, 0.35) * alpha_scanline;
    col += click_rgb * alpha_click;

    float alpha = clamp(alpha_edge + alpha_glow + alpha_scanline + alpha_click, 0.0, 1.0);
    COLOR = vec4(col, alpha);
}
