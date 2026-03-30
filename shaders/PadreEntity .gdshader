shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_nearest;

uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pixelation_res : hint_range(1.0, 512.0) = 128.0;

uniform float glitch_strength   : hint_range(0.0, 1.0) = 0.24;
uniform float flicker_strength  : hint_range(0.0, 1.0) = 0.18;
uniform float ghost_strength    : hint_range(0.0, 1.0) = 0.30;
uniform float noise_strength    : hint_range(0.0, 1.0) = 0.14;
uniform float dissolve_strength : hint_range(0.0, 1.0) = 0.0;
uniform float warp_strength     : hint_range(0.0, 1.0) = 0.12;
uniform float chroma_shift      : hint_range(0.0, 0.05) = 0.003;

uniform float tear_strength     : hint_range(0.0, 1.0) = 0.10;
uniform float block_strength    : hint_range(0.0, 1.0) = 0.06;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.10;
uniform float dither_strength   : hint_range(0.0, 1.0) = 0.45;

uniform vec4 tint : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float old_photo_mix : hint_range(0.0, 1.0) = 0.75;

// 0.0 = billboard total
// 1.0 = mantiene vertical del mundo (recomendado para el padre)
uniform float fixed_y_billboard : hint_range(0.0, 1.0) = 1.0;

// =========================
// BILLBOARD MANUAL
// =========================
void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_pos);

	vec3 up_world = vec3(0.0, 1.0, 0.0);
	vec3 right;
	vec3 up;
	vec3 forward;

	if (fixed_y_billboard > 0.5) {
		// Billboard solo en Y
		vec3 flat_to_camera = normalize(vec3(to_camera.x, 0.0, to_camera.z));
		right = normalize(cross(up_world, flat_to_camera));
		up = up_world;
		forward = normalize(cross(right, up));
	} else {
		// Billboard completo
		right = normalize(cross(up_world, to_camera));
		up = normalize(cross(to_camera, right));
		forward = to_camera;
	}

	mat3 billboard_basis = mat3(right, up, forward);

	VERTEX = billboard_basis * VERTEX;
}

// =========================
// HELPERS
// =========================
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

float pulse_noise(float t) {
	return fract(sin(t * 123.456) * 43758.5453);
}

float bayer4x4(vec2 screen_pos) {
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));

	if (x == 0 && y == 0) return 0.0625;
	if (x == 1 && y == 0) return 0.5625;
	if (x == 2 && y == 0) return 0.1875;
	if (x == 3 && y == 0) return 0.6875;

	if (x == 0 && y == 1) return 0.8125;
	if (x == 1 && y == 1) return 0.3125;
	if (x == 2 && y == 1) return 0.9375;
	if (x == 3 && y == 1) return 0.4375;

	if (x == 0 && y == 2) return 0.25;
	if (x == 1 && y == 2) return 0.75;
	if (x == 2 && y == 2) return 0.125;
	if (x == 3 && y == 2) return 0.625;

	if (x == 0 && y == 3) return 0.5;
	if (x == 1 && y == 3) return 0.0;
	if (x == 2 && y == 3) return 0.375;
	return 0.875;
}

void fragment() {
	float t = TIME;
	float eff = intensity;

	vec2 uv = UV;

	// =========================
	// 1. PIXELADO PS1
	// =========================
	if (pixelation_res > 0.0) {
		uv = floor(uv * pixelation_res) / pixelation_res;
	}

	// =========================
	// 2. TEARING SUAVE POR LÍNEAS
	// =========================
	float line_noise = noise(vec2(uv.y * 44.0, t * 3.2));
	float line_glitch = step(0.84, line_noise) * glitch_strength * tear_strength * eff;
	uv.x += (line_noise - 0.5) * 0.040 * line_glitch;

	// =========================
	// 3. BLOQUES MUY LEVES
	// =========================
	float block_noise = noise(floor(uv * vec2(10.0, 16.0)) + t * 1.8);
	vec2 block_offset = (vec2(block_noise, 1.0 - block_noise) - 0.5) * 0.010 * block_strength * glitch_strength * eff;
	uv += block_offset;

	// =========================
	// 4. WARP / ALUCINACIÓN SUAVE
	// =========================
	float affine_warp = sin(uv.y * 24.0 + t * 2.6) * warp_strength * 0.010 * eff;
	uv.x += affine_warp;
	uv.y += cos(uv.x * 16.0 - t * 2.0) * warp_strength * 0.005 * eff;

	float dream_wave_x = sin(uv.y * 18.0 + t * 1.5) * 0.003 * eff;
	float dream_wave_y = cos(uv.x * 17.0 - t * 1.35) * 0.003 * eff;
	uv += vec2(dream_wave_x, dream_wave_y);

	// =========================
	// 5. PULSO DE GLITCH CORTO
	// =========================
	float glitch_pulse = pulse_noise(floor(t * 2.2)) * step(0.93, pulse_noise(t * 1.2));
	uv.x += glitch_pulse * 0.018 * glitch_strength * eff;

	// =========================
	// 6. RGB SPLIT MODERADO
	// =========================
	vec2 shift_r = vec2(chroma_shift * (1.0 + glitch_pulse * 0.8) * eff, 0.0);
	vec2 shift_b = vec2(-chroma_shift * (1.0 + sin(t * 3.7) * 0.20) * eff, 0.0);
	vec2 shift_g = vec2(0.0, chroma_shift * 0.06 * sin(t * 3.2) * eff);

	float r = texture(albedo_tex, uv + shift_r).r;
	float g = texture(albedo_tex, uv + shift_g).g;
	float b = texture(albedo_tex, uv + shift_b).b;
	float a = texture(albedo_tex, uv).a;

	vec3 col = vec3(r, g, b);

	// =========================
	// 7. GHOSTING ESPECTRAL
	// =========================
	vec2 ghost_offset1 = vec2(
		0.009 + sin(t * 2.7) * 0.0025,
		-0.003 + cos(t * 2.3) * 0.0015
	) * ghost_strength * eff;

	vec2 ghost_offset2 = vec2(
		-0.006 + cos(t * 2.0) * 0.0015,
		0.002 + sin(t * 3.0) * 0.0012
	) * ghost_strength * eff * 0.60;

	vec4 ghost_tex1 = texture(albedo_tex, uv + ghost_offset1);
	vec4 ghost_tex2 = texture(albedo_tex, uv + ghost_offset2);

	col = mix(col, ghost_tex1.rgb, ghost_tex1.a * ghost_strength * 0.30);
	col = mix(col, ghost_tex2.rgb, ghost_tex2.a * ghost_strength * 0.14);

	// =========================
	// 8. RUIDO SUCIO
	// =========================
	float fine_noise = noise(uv * 140.0 + vec2(t * 2.2, -t * 1.6)) - 0.5;
	float coarse_noise = noise(uv * 20.0 + vec2(-t * 0.7, t * 0.4)) - 0.5;

	col += fine_noise * noise_strength * 0.07 * eff;
	col += coarse_noise * noise_strength * 0.04 * eff;

	// =========================
	// 9. FLICKER VIVO
	// =========================
	float flicker = 1.0 - (sin(t * 12.0) * 0.5 + 0.5) * flicker_strength * 0.10 * eff;
	flicker *= 0.97 + (noise(vec2(t * 5.0, 0.0)) - 0.5) * flicker_strength * 0.06 * eff;
	col *= flicker;

	// =========================
	// 10. CUANTIZACIÓN NEUTRA
	// =========================
	col = floor(col * vec3(40.0, 40.0, 40.0)) / vec3(40.0, 40.0, 40.0);

	// =========================
	// 11. TONO ESPIRITUAL / FOTO VIEJA
	// =========================
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.58);

	vec3 cold_tint = vec3(0.88, 0.92, 0.95);
	vec3 sepia_tint = vec3(1.0, 0.92, 0.75);

	vec3 final_tint = mix(cold_tint, sepia_tint, old_photo_mix);
	col *= final_tint;

	col *= mix(0.92, 0.84, old_photo_mix);

	// =========================
	// 12. DITHERING BAYER
	// =========================
	vec2 screen_pos = UV * pixelation_res;
	float bayer = bayer4x4(screen_pos);
	col += ((bayer - 0.5) / 72.0) * dither_strength;

	// =========================
	// 13. SCANLINES SUAVES
	// =========================
	float scanline = 1.0 - (0.08 * scanline_strength) + (0.08 * scanline_strength) * sin(UV.y * pixelation_res * 6.28318);
	col *= scanline;

	// =========================
	// 14. DISOLUCIÓN ESPECTRAL
	// =========================
	float dissolve_noise = noise(uv * 8.0 + vec2(t * 0.6, -t * 0.3));
	float dissolve_soft = smoothstep(0.18, 0.92, dissolve_noise);

	float dissolve_mask = mix(1.0, dissolve_soft, dissolve_strength * 0.55);
	a *= dissolve_mask;

	a *= (1.0 - dissolve_strength * 0.72);

	// =========================
	// 15. BORDES SUAVES CORRUPTOS
	// =========================
	vec2 centered_uv = UV * 2.0 - 1.0;
	float edge_dist = max(abs(centered_uv.x), abs(centered_uv.y));
	float edge_fade = 1.0 - smoothstep(0.76, 1.0, edge_dist);

	float edge_noise = noise(UV * 14.0 + vec2(t * 0.8, -t * 0.4));
	float border_break = mix(1.0, edge_noise, 0.16 * dissolve_strength);

	a *= mix(1.0, edge_fade * border_break, 0.42 * dissolve_strength);

	// =========================
	// 16. TINT FINAL
	// =========================
	col *= tint.rgb;

	ALBEDO = col;
	ALPHA = a * tint.a;

	if (ALPHA < 0.02) {
		discard;
	}
}