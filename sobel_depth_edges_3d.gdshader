shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.06, 0.08, 0.12, 1.0);
uniform float line_thickness : hint_range(0.1, 6.0, 0.1) = 1.0;
uniform float depth_threshold : hint_range(0.0001, 0.1, 0.0001) = 0.002;
uniform float normal_threshold : hint_range(0.001, 1.0, 0.001) = 0.12;
uniform float depth_weight : hint_range(0.0, 2.0, 0.01) = 0.75;
uniform float normal_weight : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float edge_softness : hint_range(0.0001, 0.25, 0.0001) = 0.02;
uniform float portal_roughness_tag : hint_range(0.0, 1.0) = 0.137;
uniform float portal_tag_epsilon : hint_range(0.0001, 0.05, 0.0001) = 0.01;

float sample_depth(vec2 uv) {
	return texture(depth_texture, uv).r;
}

vec3 sample_normal(vec2 uv) {
	vec3 packed = texture(normal_roughness_texture, uv).rgb;
	return normalize(packed * 2.0 - 1.0);
}

float sample_roughness(vec2 uv) {
	return texture(normal_roughness_texture, uv).a;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 pixel_size = 1.0 / VIEWPORT_SIZE;
	vec2 offset = pixel_size * line_thickness;

	vec2 uv_tl = SCREEN_UV + vec2(-offset.x, -offset.y);
	vec2 uv_t  = SCREEN_UV + vec2(0.0, -offset.y);
	vec2 uv_tr = SCREEN_UV + vec2(offset.x, -offset.y);
	vec2 uv_l  = SCREEN_UV + vec2(-offset.x, 0.0);
	vec2 uv_r  = SCREEN_UV + vec2(offset.x, 0.0);
	vec2 uv_bl = SCREEN_UV + vec2(-offset.x, offset.y);
	vec2 uv_b  = SCREEN_UV + vec2(0.0, offset.y);
	vec2 uv_br = SCREEN_UV + vec2(offset.x, offset.y);

	float d_tl = sample_depth(uv_tl);
	float d_t  = sample_depth(uv_t);
	float d_tr = sample_depth(uv_tr);
	float d_l  = sample_depth(uv_l);
	float d_r  = sample_depth(uv_r);
	float d_bl = sample_depth(uv_bl);
	float d_b  = sample_depth(uv_b);
	float d_br = sample_depth(uv_br);

	float r_tl = sample_roughness(uv_tl);
	float r_t  = sample_roughness(uv_t);
	float r_tr = sample_roughness(uv_tr);
	float r_l  = sample_roughness(uv_l);
	float r_c  = sample_roughness(SCREEN_UV);
	float r_r  = sample_roughness(uv_r);
	float r_bl = sample_roughness(uv_bl);
	float r_b  = sample_roughness(uv_b);
	float r_br = sample_roughness(uv_br);

	float d_sobel_x = (-d_tl - 2.0 * d_l - d_bl) + (d_tr + 2.0 * d_r + d_br);
	float d_sobel_y = (-d_tl - 2.0 * d_t - d_tr) + (d_bl + 2.0 * d_b + d_br);
	float depth_edge = length(vec2(d_sobel_x, d_sobel_y));

	vec3 n_tl = sample_normal(uv_tl);
	vec3 n_t  = sample_normal(uv_t);
	vec3 n_tr = sample_normal(uv_tr);
	vec3 n_l  = sample_normal(uv_l);
	vec3 n_r  = sample_normal(uv_r);
	vec3 n_bl = sample_normal(uv_bl);
	vec3 n_b  = sample_normal(uv_b);
	vec3 n_br = sample_normal(uv_br);

	vec3 n_sobel_x = (-n_tl - 2.0 * n_l - n_bl) + (n_tr + 2.0 * n_r + n_br);
	vec3 n_sobel_y = (-n_tl - 2.0 * n_t - n_tr) + (n_bl + 2.0 * n_b + n_br);
	float normal_edge = length(n_sobel_x) + length(n_sobel_y);

	float depth_mask = smoothstep(depth_threshold, depth_threshold + edge_softness, depth_edge);
	float normal_mask = smoothstep(normal_threshold, normal_threshold + edge_softness, normal_edge);
	float edge_mask = clamp(depth_mask * depth_weight + normal_mask * normal_weight, 0.0, 1.0);
	bool portal_tag_present = abs(r_tl - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_t - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_tr - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_l - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_c - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_r - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_bl - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_b - portal_roughness_tag) <= portal_tag_epsilon
		|| abs(r_br - portal_roughness_tag) <= portal_tag_epsilon;
	if (portal_tag_present) {
		edge_mask = 0.0;
	}

	vec4 scene_color = texture(screen_texture, SCREEN_UV);
	vec3 mixed_color = mix(scene_color.rgb, line_color.rgb, edge_mask * line_color.a);

	ALBEDO = mixed_color;
	ALPHA = 1.0;
}
