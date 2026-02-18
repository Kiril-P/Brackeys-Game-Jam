shader_type sky;

uniform vec4 deep_color : source_color = vec4(0.01, 0.03, 0.07, 1.0);
uniform vec4 mid_color : source_color = vec4(0.08, 0.22, 0.42, 1.0);
uniform vec4 glow_color : source_color = vec4(0.35, 0.86, 1.0, 1.0);
uniform float fractal_scale : hint_range(0.5, 8.0, 0.1) = 2.2;
uniform float warp_strength : hint_range(0.0, 2.0, 0.01) = 0.45;
uniform float animation_speed : hint_range(0.0, 3.0, 0.01) = 0.18;
uniform float contrast : hint_range(0.2, 2.0, 0.01) = 1.15;
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		value += amp * noise2d(p * freq);
		freq *= 2.0;
		amp *= 0.5;
	}
	return value;
}

void sky() {
	vec2 uv = SKY_COORDS;
	float horizon = clamp(uv.y, 0.0, 1.0);

	float t = TIME * animation_speed;
	vec2 p = (uv - vec2(0.5)) * fractal_scale;
	vec2 warp = vec2(
		fbm(p + vec2(0.0, t)),
		fbm(p + vec2(4.13, -t))
	) - 0.5;
	p += warp * warp_strength;

	float f = fbm(p + vec2(t * 0.35, -t * 0.22));
	f = pow(clamp(f, 0.0, 1.0), contrast);

	vec3 base = mix(deep_color.rgb, mid_color.rgb, horizon);
	vec3 fractal_tint = mix(base, glow_color.rgb, f);
	vec3 final_color = mix(base, fractal_tint, intensity);

	COLOR = final_color;
}
