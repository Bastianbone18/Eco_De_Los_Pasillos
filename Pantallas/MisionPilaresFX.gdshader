shader_type canvas_item;

uniform float progress_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float mission_progress : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;
uniform float ghost_strength : hint_range(0.0, 1.0) = 0.06;
uniform float chroma_strength : hint_range(0.0, 0.02) = 0.0018;
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.03;
uniform float band_shift_strength : hint_range(0.0, 0.20) = 0.02;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.08;
uniform float darkness_strength : hint_range(0.0, 1.0) = 0.08;
uniform float red_push : hint_range(0.0, 1.0) = 0.12;
uniform float curve_wave_strength : hint_range(0.0, 0.10) = 0.01;
uniform float scream_line_strength : hint_range(0.0, 1.0) = 0.0;

uniform vec4 overlay_tint : source_color = vec4(0.18, 0.05, 0.05, 0.16);

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

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float eff = progress_intensity;
	float pulse = pulse_amount;

	float ramp = fract(t * 0.22 + uv.y * 0.18) * 2.0 - 1.0;
	uv.x += ramp * curve_wave_strength * eff;
	uv.x += sin(uv.y * 12.0 + t * 1.8) * curve_wave_strength * 0.35 * eff;
	uv.y += cos(uv.x * 10.0 - t * 1.5) * curve_wave_strength * 0.10 * eff;

	vec3 col = overlay_tint.rgb;
	float alpha = overlay_tint.a;

	vec2 ghost_uv = uv;
	ghost_uv += vec2(
		0.008 + sin(t * 2.7) * 0.002,
		-0.002 + cos(t * 2.1) * 0.001
	) * ghost_strength * eff;

	float ghost_noise = noise(ghost_uv * 18.0 + vec2(t * 0.8, -t * 0.4));
	col += vec3(ghost_noise) * ghost_strength * eff * 0.08;

	float band_noise = noise(vec2(floor(uv.y * 28.0), floor(t * 4.0)));
	float band_mask = step(0.80, band_noise) * glitch_strength * eff;

	col *= 1.0 - band_mask * 0.18;
	alpha += band_mask * 0.06;

	float band_shift = (band_noise - 0.5) * band_shift_strength * band_mask * 3.0;
	col.r += band_shift * 0.12;
	col.b -= band_shift * 0.10;

	float chroma = chroma_strength * eff * (0.4 + pulse * 0.6);
	col.r += chroma * 5.0;
	col.b -= chroma * 4.0;

	float fine_noise = noise(uv * 220.0 + vec2(t * 5.0, -t * 3.2)) - 0.5;
	float coarse_noise = noise(uv * 28.0 + vec2(-t * 0.9, t * 0.5)) - 0.5;

	col += fine_noise * noise_strength * 0.18;
	col += coarse_noise * noise_strength * 0.10;

	alpha += abs(fine_noise) * noise_strength * 0.05;
	alpha += abs(coarse_noise) * noise_strength * 0.03;

	float scan = sin(uv.y * 1100.0) * 0.5 + 0.5;
	scan = mix(1.0, 0.86 + scan * 0.14, scanline_strength);
	col *= scan;

	float scream = sin(uv.y * 170.0 + t * 16.0) * sin(uv.y * 64.0 - t * 8.0);
	scream = scream * 0.5 + 0.5;

	float scream_band = step(0.76, scream);
	col *= mix(1.0, 0.78, scream_band * scream_line_strength * eff);
	alpha += scream_band * scream_line_strength * eff * 0.035;

	col.r += red_push * eff * 0.20;
	col.g -= red_push * eff * 0.04;
	col.b -= red_push * eff * 0.06;

	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.94, 0.18, dist);
	col *= mix(1.0, vignette, vignette_strength);

	col *= 1.0 - darkness_strength * eff;

	col += vec3(flash_amount * 0.12);
	alpha += flash_amount * 0.025;

	alpha *= 0.65 + eff * 0.35;
	alpha *= 0.92 + mission_progress * 0.08;
	alpha = clamp(alpha, 0.0, 0.32);

	COLOR = vec4(col, alpha);
}