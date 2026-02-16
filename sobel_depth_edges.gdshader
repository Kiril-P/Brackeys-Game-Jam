shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.06, 0.08, 0.12, 1.0);
uniform float line_thickness : hint_range(0.1, 6.0, 0.1) = 1.0;
uniform float depth_threshold : hint_range(0.0001, 0.1, 0.0001) = 0.002;

float sample_depth(vec2 uv) {
	return texture(depth_texture, uv).r;
}

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(depth_texture, 0));
	vec2 offset = pixel_size * line_thickness;

	float tl = sample_depth(SCREEN_UV + vec2(-offset.x, -offset.y));
	float  t = sample_depth(SCREEN_UV + vec2(0.0, -offset.y));
	float tr = sample_depth(SCREEN_UV + vec2(offset.x, -offset.y));
	float  l = sample_depth(SCREEN_UV + vec2(-offset.x, 0.0));
	float  r = sample_depth(SCREEN_UV + vec2(offset.x, 0.0));
	float bl = sample_depth(SCREEN_UV + vec2(-offset.x, offset.y));
	float  b = sample_depth(SCREEN_UV + vec2(0.0, offset.y));
	float br = sample_depth(SCREEN_UV + vec2(offset.x, offset.y));

	float sobel_x = (-tl - 2.0 * l - bl) + (tr + 2.0 * r + br);
	float sobel_y = (-tl - 2.0 * t - tr) + (bl + 2.0 * b + br);
	float edge_strength = length(vec2(sobel_x, sobel_y));

	float edge_mask = step(depth_threshold, edge_strength);

	vec4 scene_color = texture(screen_texture, SCREEN_UV);
	COLOR = mix(scene_color, line_color, edge_mask * line_color.a);
}
