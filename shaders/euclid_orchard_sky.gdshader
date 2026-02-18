shader_type sky;

uniform vec4 sky_bottom_color : source_color = vec4(0.06, 0.09, 0.14, 1.0);
uniform vec4 sky_top_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform vec4 structure_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.45, 0.76, 1.0, 1.0);

uniform float cell_size : hint_range(6.0, 40.0, 0.5) = 14.0;
uniform float pillar_thickness : hint_range(0.08, 2.0, 0.01) = 0.42;
uniform float arch_height : hint_range(1.0, 14.0, 0.1) = 4.8;
uniform float floor_thickness : hint_range(0.02, 1.2, 0.01) = 0.14;

uniform int quality_tier : hint_range(0, 2, 1) = 0; // 0 = low, 1 = medium, 2 = high
uniform float hit_epsilon : hint_range(0.0005, 0.05, 0.0005) = 0.0055;
uniform float fog_density : hint_range(0.0, 0.15, 0.001) = 0.028;
uniform float contrast : hint_range(0.5, 3.0, 0.01) = 1.35;
uniform vec3 light_dir = vec3(0.65, 0.45, 0.62);
uniform float orbit_amount : hint_range(0.0, 3.0, 0.01) = 0.16;
uniform float orbit_speed : hint_range(0.0, 1.5, 0.01) = 0.08;
uniform bool fallback_gradient_only = false;

float sd_box(vec3 p, vec3 b) {
	vec3 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

vec3 repeat_centered(vec3 p, float s) {
	return mod(p + 0.5 * s, s) - 0.5 * s;
}

vec2 scene_distance(vec3 p) {
	vec3 rp = repeat_centered(p, cell_size);
	float edge = cell_size * 0.36;
	float half_arch = max(arch_height * 0.5, 0.2);

	// Four repeating columns on cell corners.
	vec3 corner_local = vec3(abs(rp.x) - edge, rp.y - half_arch, abs(rp.z) - edge);
	float columns = sd_box(corner_local, vec3(pillar_thickness, half_arch, pillar_thickness));

	// Cross beams connecting columns.
	float beam_x = sd_box(
		vec3(rp.x, rp.y - arch_height, abs(rp.z) - edge),
		vec3(edge, pillar_thickness, pillar_thickness)
	);
	float beam_z = sd_box(
		vec3(abs(rp.x) - edge, rp.y - arch_height, rp.z),
		vec3(pillar_thickness, pillar_thickness, edge)
	);

	// Thin repeating floor slab for orchard "platform" readability.
	float floor_slab = sd_box(
		vec3(rp.x, rp.y + floor_thickness, rp.z),
		vec3(edge + pillar_thickness * 0.7, floor_thickness, edge + pillar_thickness * 0.7)
	);

	float d = min(min(columns, beam_x), min(beam_z, floor_slab));

	// Cell index gives subtle variation that reinforces depth and repetition.
	vec3 cell = floor((p + 0.5 * cell_size) / cell_size);
	float cell_hash = fract(sin(dot(cell, vec3(7.0, 31.0, 17.0))) * 43758.5453);
	return vec2(d, cell_hash);
}

vec3 estimate_normal(vec3 p) {
	float e = max(hit_epsilon * 2.0, 0.001);
	vec2 k = vec2(1.0, -1.0);
	return normalize(
		k.xyy * scene_distance(p + k.xyy * e).x +
		k.yyx * scene_distance(p + k.yyx * e).x +
		k.yxy * scene_distance(p + k.yxy * e).x +
		k.xxx * scene_distance(p + k.xxx * e).x
	);
}

float get_step_budget() {
	if (quality_tier <= 0) {
		return 48.0;
	}
	if (quality_tier == 1) {
		return 72.0;
	}
	return 104.0;
}

float get_max_distance() {
	if (quality_tier <= 0) {
		return 150.0;
	}
	if (quality_tier == 1) {
		return 220.0;
	}
	return 320.0;
}

vec2 rotate2d(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void sky() {
	vec3 rd = normalize(EYEDIR);
	float h = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 bg = mix(sky_bottom_color.rgb, sky_top_color.rgb, h);

	vec3 color = bg;
	if (!fallback_gradient_only) {
	float t_orbit = TIME * orbit_speed;
	vec2 rotated_xz = rotate2d(rd.xz, t_orbit);
	rd.xz = mix(rd.xz, rotated_xz, clamp(orbit_amount, 0.0, 1.0));

	vec3 ro = vec3(0.0, arch_height * 0.68, 0.0);
	float max_dist = get_max_distance();
	float step_budget = get_step_budget();

	float t = 0.0;
	float hit_mask = 0.0;
	float cell_id = 0.0;

	for (int i = 0; i < 128; i++) {
		if (float(i) >= step_budget) {
			break;
		}
		vec3 p = ro + rd * t;
		vec2 info = scene_distance(p);
		if (info.x < hit_epsilon) {
			hit_mask = 1.0;
			cell_id = info.y;
			break;
		}
		t += max(info.x * 0.85, 0.002);
		if (t > max_dist) {
			break;
		}
	}

		color = bg;
		if (hit_mask > 0.5) {
			vec3 hp = ro + rd * t;
			vec3 n = estimate_normal(hp);
			vec3 l = normalize(light_dir);
			float diff = max(dot(n, l), 0.0);
			float rim = pow(1.0 - max(dot(n, -rd), 0.0), 2.6);
			float hash_tint = mix(0.9, 1.1, cell_id);

			vec3 lit = structure_color.rgb * (0.22 + diff * 0.95) * hash_tint;
			lit += accent_color.rgb * rim * 0.5;
			float fog = 1.0 - exp(-t * fog_density);
			color = mix(lit, bg, clamp(fog, 0.0, 1.0));
		}

		color = pow(max(color, vec3(0.0)), vec3(1.0 / contrast));
	}
	COLOR = color;
}
