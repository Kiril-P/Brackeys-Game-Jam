shader_type canvas_item;
render_mode unshaded;

uniform vec4 line_color : source_color = vec4(0.62, 0.94, 1.0, 0.26);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float density : hint_range(2.0, 18.0) = 9.0;
uniform float warp : hint_range(0.0, 1.0) = 0.42;
uniform float motion_speed : hint_range(0.0, 3.0) = 0.75;

vec2 rotate2d(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, -s), vec2(s, c)) * v;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * motion_speed;
	vec2 p = uv;

	// Kaleidoscopic fold with inverse-distance warping for non-euclidean feel.
	for (int i = 0; i < 3; i++) {
		p = rotate2d(p, t * 0.18 + float(i) * 0.85);
		float d = max(dot(p, p), 0.18);
		p = abs(p) / d - vec2(0.58 + warp * 0.2);
	}

	vec2 grid = abs(fract((p + 1.0) * density) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.045, min(grid.x, grid.y));
	float pulse = 0.55 + 0.45 * sin(t + uv.x * 2.3 + uv.y * 2.8);
	float vignette = 1.0 - smoothstep(0.25, 1.35, length(uv));
	float alpha = line * pulse * intensity * vignette * line_color.a;

	COLOR = vec4(line_color.rgb, alpha);
}
