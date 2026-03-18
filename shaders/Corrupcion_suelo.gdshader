shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// =====================================================
// TEXTURAS BASE
// =====================================================
uniform sampler2D albedo_tex    : source_color,       filter_nearest_mipmap, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_r,   filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_tex    : hint_normal,        filter_nearest_mipmap, repeat_enable;
uniform sampler2D metallic_tex  : source_color,       filter_nearest_mipmap, repeat_enable;
uniform sampler2D grunge_tex    : source_color,       filter_nearest_mipmap, repeat_enable;

// =====================================================
// UV / ESCALAS
// =====================================================
uniform float uv_scale = 1.0;
uniform float grunge_scale_a = 2.4;
uniform float grunge_scale_b = 5.2;

// =====================================================
// CONTROL PRINCIPAL
// =====================================================
uniform float corruption : hint_range(0.0, 1.0) = 0.0;

// =====================================================
// COLOR / CORRUPCIÓN
// =====================================================
uniform vec3 corruption_tint : source_color = vec3(0.10, 0.00, 0.00);
uniform vec3 blood_tint      : source_color = vec3(0.16, 0.01, 0.01);
uniform vec3 crack_tint      : source_color = vec3(0.01, 0.00, 0.00);

uniform float corruption_darkness : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_boost     : hint_range(0.0, 1.0) = 0.12;
uniform float metallic_reduction  : hint_range(0.0, 1.0) = 0.15;
uniform float normal_boost        : hint_range(0.0, 3.0) = 1.05;

// =====================================================
// TEMBLOR / TERREMOTO LATERAL
// MUY SUAVE, para no marear
// =====================================================
uniform float quake_strength : hint_range(0.0, 0.5) = 0.006;
uniform float quake_speed = 4.2;
uniform float quake_secondary_speed = 7.5;
uniform float quake_skew_strength : hint_range(0.0, 0.1) = 0.0025;
uniform float quake_progress_max : hint_range(0.0, 1.0) = 0.28;

// =====================================================
// DISTORSIÓN UV / RESPIRACIÓN
// =====================================================
uniform float uv_breath_strength : hint_range(0.0, 0.05) = 0.0015;
uniform float radial_distort_strength : hint_range(0.0, 0.05) = 0.0012;
uniform float uv_quake_strength : hint_range(0.0, 0.05) = 0.0018;

// =====================================================
// PULSO / VIDA
// =====================================================
uniform float pulse_speed = 0.85;
uniform float pulse_strength = 0.75;
uniform float secondary_pulse_strength = 0.25;

// =====================================================
// VENAS / GRIETAS
// =====================================================
uniform float vein_strength : hint_range(0.0, 2.0) = 0.55;
uniform float crack_strength : hint_range(0.0, 2.0) = 0.75;
uniform float vein_scroll_speed = 0.05;
uniform float crack_scroll_speed = 0.04;

// =====================================================
// EMISIÓN
// =====================================================
uniform vec3 vein_emission_color : source_color = vec3(0.40, 0.03, 0.02);
uniform vec3 core_emission_color : source_color = vec3(0.70, 0.08, 0.03);

uniform float emission_strength : hint_range(0.0, 10.0) = 0.28;
uniform float emission_pulse_strength : hint_range(0.0, 5.0) = 0.45;
uniform float crack_emission_strength : hint_range(0.0, 5.0) = 0.15;

// =====================================================
// PS1 / ANALÓGICO
// =====================================================
uniform float color_quantization : hint_range(0.0, 1.0) = 0.20;
uniform float dither_strength    : hint_range(0.0, 1.0) = 0.05;
uniform float scanline_strength  : hint_range(0.0, 1.0) = 0.08;
uniform float scanline_density   = 180.0;
uniform float noise_strength     : hint_range(0.0, 1.0) = 0.015;

// =====================================================
// HELPERS
// =====================================================
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float grain(vec2 uv, float t) {
	return fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
}

// =====================================================
// VERTEX
// =====================================================
void vertex() {
	float c = clamp(corruption, 0.0, 1.0);
	float quake_factor = c * quake_progress_max;
	float t = TIME;

	float quake_x =
		sin(t * quake_speed) * 0.5 +
		sin(t * quake_secondary_speed) * 0.18;

	float quake_z =
		cos(t * (quake_speed * 0.83)) * 0.32 +
		sin(t * (quake_secondary_speed * 0.71)) * 0.12;

	VERTEX.x += quake_x * quake_strength * quake_factor;
	VERTEX.z += quake_z * quake_strength * quake_factor;

	float skew = sin(t * (quake_speed * 0.57) + UV.y * 3.14159);
	VERTEX.x += (UV.y - 0.5) * skew * quake_skew_strength * quake_factor;
}

// =====================================================
// FRAGMENT
// =====================================================
void fragment() {
	float t = TIME;
	float c = clamp(corruption, 0.0, 1.0);
	float intensity = pow(c, 1.05);

	float beat1 = pow(max(0.0, sin(t * pulse_speed * 6.28318)), 5.5);
	float beat2 = pow(max(0.0, sin(t * pulse_speed * 6.28318 - 0.55)), 8.0) * secondary_pulse_strength;
	float pulse = clamp(beat1 + beat2, 0.0, 1.2);

	vec2 uv = UV * uv_scale;

	vec2 center = vec2(0.5, 0.5);
	vec2 to_center = uv - center;
	float radius = length(to_center);
	float angle = atan(to_center.y, to_center.x);

	float breath_uv =
		sin(t * 1.3 + radius * 18.0) * 0.5 +
		cos(t * 0.9 - angle * 3.0) * 0.5;

	uv += normalize(to_center + vec2(0.0001)) * breath_uv * uv_breath_strength * intensity;

	float radial =
		sin(angle * 4.0 + t * 1.1) *
		cos(radius * 16.0 - t * 1.4);

	uv += normalize(to_center + vec2(0.0001)) * radial * radial_distort_strength * intensity;

	float quake_factor = c * quake_progress_max;

	vec2 uv_quake = vec2(
		(sin(t * quake_speed) + sin(t * quake_secondary_speed) * 0.35),
		(cos(t * quake_speed * 0.7) + sin(t * quake_secondary_speed * 0.4) * 0.22)
	);

	uv += uv_quake * uv_quake_strength * quake_factor;

	vec2 guv_a = UV * grunge_scale_a + vec2(t * vein_scroll_speed * 0.05, -t * vein_scroll_speed * 0.03);
	vec2 guv_b = UV * grunge_scale_b + vec2(-t * crack_scroll_speed * 0.02, t * crack_scroll_speed * 0.03);

	vec4 albedo_sample = texture(albedo_tex, uv);
	float roughness_sample = texture(roughness_tex, uv).r;
	vec3 normal_sample = texture(normal_tex, uv).rgb;
	float metallic_sample = texture(metallic_tex, uv).r;

	float g1 = texture(grunge_tex, guv_a).r;
	float g2 = texture(grunge_tex, guv_b).r;

	float dirty_field = mix(g1, g2, 0.35);
	float dirty_mask = smoothstep(0.48, 0.82, dirty_field) * intensity;

	float vein_field = abs(g1 - g2);
	vein_field += fbm(guv_a * 1.25 + vec2(t * 0.08, -t * 0.05)) * 0.32;

	float vein_mask = smoothstep(0.58 - c * 0.06, 0.84 - c * 0.03, vein_field);
	vein_mask *= smoothstep(0.28, 1.0, c);
	vein_mask *= vein_strength;
	vein_mask *= (0.35 + pulse * 0.55);

	float crack_field = 1.0 - abs(g1 - 0.5) * 2.0;
	crack_field = 1.0 - crack_field;
	crack_field += (1.0 - g2) * 0.12;

	float crack_mask = smoothstep(0.82 - c * 0.05, 0.97 - c * 0.03, crack_field);
	crack_mask *= smoothstep(0.40, 1.0, c);
	crack_mask *= crack_strength;

	float crack_pulse = crack_mask * (0.25 + pulse * 0.45);

	vec3 col = albedo_sample.rgb;

	vec3 darkened = col * (1.0 - corruption_darkness * dirty_mask);
	darkened = mix(darkened, darkened + corruption_tint, dirty_mask * 0.35);
	darkened = mix(darkened, darkened + blood_tint, vein_mask * 0.18);
	darkened = mix(darkened, crack_tint, crack_mask * 0.28);

	col = darkened;

	ROUGHNESS = clamp(
		roughness_sample + dirty_mask * roughness_boost + crack_mask * 0.08,
		0.0,
		1.0
	);

	METALLIC = clamp(
		metallic_sample - dirty_mask * metallic_reduction - crack_mask * 0.10,
		0.0,
		1.0
	);

	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = normal_boost + dirty_mask * 0.08 + crack_mask * 0.12;

	vec3 emission = vec3(0.0);

	emission += vein_emission_color * vein_mask * emission_strength * (0.12 + pulse * emission_pulse_strength) * intensity;
	emission += core_emission_color * crack_pulse * crack_emission_strength * intensity;

	float global_breath = smoothstep(0.70, 1.0, c) * (0.08 + pulse * 0.08);
	emission += blood_tint * global_breath * 0.18;

	if (noise_strength > 0.0) {
		float g = grain(uv + t, t);
		float n = (g - 0.5) * noise_strength;
		col += n * 0.18;
		emission += n * 0.02;
	}

	if (scanline_strength > 0.0) {
		float scan = sin(SCREEN_UV.y * scanline_density * 2.0 + t * 4.0) * 0.5 + 0.5;
		scan = pow(scan, 2.0);
		float darken_scan = 1.0 - scanline_strength * (1.0 - scan);
		col *= darken_scan;
		emission *= darken_scan;
	}

	if (color_quantization > 0.0) {
		float levels = 1.0 / color_quantization;
		col = floor(col * levels + 0.5) / levels;

		if (dither_strength > 0.0) {
			float d = grain(UV * 64.0 + vec2(t * 0.1, t * 0.2), t) - 0.5;
			col += d * dither_strength / levels;
		}
	}

	ALBEDO = col;
	EMISSION = max(emission, vec3(0.0));
}