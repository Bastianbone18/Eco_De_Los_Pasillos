shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// =========================
// TEXTURA
// =========================
uniform sampler2D pentagram_tex : source_color, filter_nearest;

// =========================
// COLORES BASE
// =========================
uniform vec3 color_off = vec3(0.08, 0.01, 0.01);
uniform vec3 color_blood = vec3(0.55, 0.02, 0.02);
uniform vec3 color_hot = vec3(0.95, 0.12, 0.03);
uniform vec3 color_core = vec3(1.0, 0.24, 0.05);
uniform vec3 color_blackblood = vec3(0.16, 0.0, 0.0);

// =========================
// CONTROL PRINCIPAL
// =========================
uniform float active = 0.0;
uniform float pulse_speed = 1.0;
uniform float pulse_strength = 1.1;
uniform float emission_strength = 1.8;
uniform float glitch_strength = 0.0015;
uniform float alpha_cut = 0.5;

// =========================
// EFECTOS PS1 / TERROR BASE
// =========================
uniform float time_scale = 1.0;
uniform float color_quantization = 0.2;
uniform float dither_strength = 0.15;
uniform float scanline_strength = 0.25;
uniform float scanline_density = 120.0;
uniform float noise_strength = 0.1;
uniform float flicker_strength = 0.3;
uniform float vertex_wobble = 0.02;
uniform float glow_clamp = 0.8;

// =========================
// NUEVOS EFECTOS HORROR 100
// =========================

// Respira / late con caos
uniform float chaos_breath_strength = 0.18;
uniform float chaos_breath_speed = 0.65;

// Fiebre / snapping analógico en vértices
uniform float fever_snap_strength = 0.025;   // 0.0 - 0.08
uniform float fever_snap_rate = 42.0;        // más alto = más nervioso

// Sangrado / arrastre de textura
uniform float bleed_strength = 0.012;        // 0.0 - 0.03
uniform float bleed_speed = 1.2;

// Fallos tipo CD / lectura mala
uniform float cd_glitch_strength = 0.02;     // 0.0 - 0.06
uniform float cd_glitch_rate = 18.0;

// Líneas de ruido vivas
uniform float scream_line_strength = 0.18;   // 0.0 - 0.5
uniform float scream_line_density = 170.0;

// Ondas de pánico
uniform float panic_wave_strength = 0.01;    // 0.0 - 0.04
uniform float panic_wave_speed = 2.0;
uniform float panic_wave_density = 24.0;

// Distorsión radial enfermiza
uniform float radial_distort_strength = 0.012; // 0.0 - 0.03

// =========================
// HASH / NOISE
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

float grain(vec2 uv, float t) {
	return fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
}

// =========================
// VERTEX
// =========================
void vertex() {
	if (active > 0.0) {
		float t = TIME * time_scale;
		vec3 pos = VERTEX;

		// 1) Wobble base ya existente
		if (vertex_wobble > 0.0) {
			float offset = sin(pos.x * 10.0 + t * 2.0) *
						   cos(pos.y * 8.0 + t * 2.0) *
						   sin(pos.z * 12.0 + t * 2.6);
			pos.xy += offset * vertex_wobble * active;
		}

		// 2) Fiebre: snapping nervioso analógico
		if (fever_snap_strength > 0.0) {
			float snap_time = floor(t * fever_snap_rate) / max(fever_snap_rate, 0.001);
			float sx = sin(pos.x * 31.0 + snap_time * 13.0);
			float sy = cos(pos.z * 27.0 + snap_time * 17.0);
			vec2 snap_vec = vec2(sx, sy) * fever_snap_strength * active;

			// cuantizado brusco
			snap_vec = floor(snap_vec * 128.0) / 128.0;
			pos.xz += snap_vec;
		}

		// 3) Respiración caótica del plano
		if (chaos_breath_strength > 0.0) {
			float breath =
				sin(t * chaos_breath_speed * 2.0) * 0.5 +
				sin(t * chaos_breath_speed * 3.7 + pos.x * 4.0) * 0.3 +
				cos(t * chaos_breath_speed * 2.8 + pos.z * 3.0) * 0.2;

			pos.y += breath * chaos_breath_strength * active;
		}

		// 4) Onda de pánico en geometría
		if (panic_wave_strength > 0.0) {
			float r = length(pos.xz);
			float panic = sin(r * panic_wave_density - t * panic_wave_speed * 6.28318);
			pos.y += panic * panic_wave_strength * active;
		}

		VERTEX = pos;
	}
}



// =========================
// FRAGMENT
// =========================
void fragment() {
	float t = TIME * time_scale;
	float tt = t * pulse_speed;

	vec2 uv = UV;

	// -------------------------
	// CENTRO UV PARA EFECTOS RADIALES
	// -------------------------
	vec2 center = vec2(0.5, 0.5);
	vec2 to_center = uv - center;
	float radius = length(to_center);
	float angle = atan(to_center.y, to_center.x);

	// -------------------------
	// 1) RESPIRACIÓN / CAOS EN UV
	// -------------------------
	if (chaos_breath_strength > 0.0 && active > 0.0) {
		float breath_uv =
			sin(t * chaos_breath_speed * 1.8 + radius * 20.0) * 0.003 +
			cos(t * chaos_breath_speed * 2.7 - angle * 4.0) * 0.002;
		uv += normalize(to_center + vec2(0.0001)) * breath_uv * active;
	}

	// -------------------------
	// 2) GLITCH BASE
	// -------------------------
	if (glitch_strength > 0.0 && active > 0.0) {
		float band = step(0.988, sin(t * 7.0 + uv.y * 45.0));
		uv.x += (band - 0.5) * glitch_strength * active;
	}

	// -------------------------
	// 3) FALLOS DE CD
	// -------------------------
	if (cd_glitch_strength > 0.0 && active > 0.0) {
		float cd_time = floor(t * cd_glitch_rate) / max(cd_glitch_rate, 0.001);
		float cd_jump = step(0.84, noise(vec2(cd_time * 2.1, floor(uv.y * 28.0))));
		float cd_shift = (noise(vec2(cd_time * 7.3, floor(uv.y * 16.0))) - 0.5) * cd_glitch_strength;
		uv.x += cd_shift * cd_jump * active;

		float radial_jump = step(0.9, noise(vec2(cd_time * 4.0, 9.0)));
		uv += normalize(to_center + vec2(0.0001)) * cd_glitch_strength * 0.35 * radial_jump * active;
	}

	// -------------------------
	// 4) ONDAS DE PÁNICO UV
	// -------------------------
	if (panic_wave_strength > 0.0 && active > 0.0) {
		float panic_wave =
			sin(radius * panic_wave_density - t * panic_wave_speed * 6.28318) *
			panic_wave_strength *
			(1.0 - radius);
		uv += normalize(to_center + vec2(0.0001)) * panic_wave * active;
	}

	// -------------------------
	// 5) DISTORSIÓN RADIAL ENFERMIZA
	// -------------------------
	if (radial_distort_strength > 0.0 && active > 0.0) {
		float radial =
			sin(angle * 6.0 + t * 2.2) *
			cos(radius * 30.0 - t * 3.1);
		uv += normalize(to_center + vec2(0.0001)) * radial * radial_distort_strength * active;
	}

	// -------------------------
	// 6) SANGRADO / ARRASTRE DE TEXTURA
	// -------------------------
	vec2 bleed_uv = uv;
	if (bleed_strength > 0.0 && active > 0.0) {
		float bleed_noise = noise(vec2(uv.x * 6.0, uv.y * 11.0 + t * bleed_speed));
		float bleed_dir = sin(t * bleed_speed + uv.x * 13.0) * 0.5 + 0.5;
		bleed_uv.y += bleed_strength * bleed_noise * active * (0.6 + bleed_dir);
		bleed_uv.x += (bleed_noise - 0.5) * bleed_strength * 0.35 * active;
	}

	// -------------------------
	// TEXTURA BASE + SANGRADO
	// -------------------------
	vec4 tex = texture(pentagram_tex, uv);
	vec4 tex_bleed = texture(pentagram_tex, bleed_uv);

	float mask = step(alpha_cut, tex.a);
	if (mask < 0.5) {
		discard;
	}

	// bleed mask adicional
	float bleed_mask = step(alpha_cut, tex_bleed.a) * active;

	// -------------------------
	// PULSACIONES / LATIDO
	// -------------------------
	float beat1 = pow(max(0.0, sin(tt * 6.28318)), 6.0);
	float beat2 = pow(max(0.0, sin(tt * 6.28318 - 0.55)), 10.0) * 0.35;
	float pulse = 0.5 + 0.5 * sin(tt * 6.28318);

	// latido extra caótico
	float chaos_beat =
		sin(tt * 12.7) * 0.5 +
		cos(tt * 8.9 + radius * 14.0) * 0.35 +
		sin(tt * 17.0 - angle * 3.0) * 0.15;
	chaos_beat = chaos_beat * 0.5 + 0.5;

	float alive = active * (
		0.14 +
		pulse * pulse_strength * 0.14 +
		beat1 * 0.78 +
		beat2 * 0.30 +
		chaos_beat * 0.18
	);

	// -------------------------
	// COLOR BASE
	// -------------------------
	vec3 col = mix(color_off, color_blood, clamp(alive * 1.5, 0.0, 1.0));
	col = mix(col, color_hot, clamp((alive - 0.35) * 1.8, 0.0, 1.0));
	col = mix(col, color_core, clamp(beat1 * 0.24 + beat2 * 0.18 + chaos_beat * 0.12, 0.0, 1.0));

	// Sangrado oscuro sobre el color
	col = mix(col, color_blackblood, bleed_mask * 0.18 * (0.5 + chaos_beat * 0.5));

	// -------------------------
	// EMISIÓN BASE
	// -------------------------
	float emission_base = active * (0.14 + beat1 * 0.9 + beat2 * 0.35 + chaos_beat * 0.25);
	vec3 emission = col * emission_strength * emission_base;

	// Emisión extra por sangrado vivo
	emission += color_blood * bleed_mask * 0.25 * active;

	// =========================
	// EFECTOS HORROR PS1
	// =========================

	// 1. Ruido analógico / snow
	if (noise_strength > 0.0) {
		float g = grain(uv + t, t);
		float noise_factor = (g - 0.5) * noise_strength;
		col += noise_factor * 0.5;
		emission += noise_factor * emission;
	}

	// 2. Scanlines
	if (scanline_strength > 0.0) {
		float scan = sin(uv.y * scanline_density * 2.0 + t * 5.0) * 0.5 + 0.5;
		scan = pow(scan, 2.0);
		float darken = 1.0 - scanline_strength * (1.0 - scan);
		col *= darken;
		emission *= darken;
	}

	// 3. Líneas de ruido "gime con ruido"
	if (scream_line_strength > 0.0) {
		float scream =
			sin(uv.y * scream_line_density + t * 22.0) *
			sin(uv.y * (scream_line_density * 0.37) - t * 11.0);
		scream = scream * 0.5 + 0.5;

		float scream_band = step(0.72, scream);
		float scream_dark = 1.0 - scream_band * scream_line_strength * (0.35 + chaos_beat * 0.65);

		col *= scream_dark;
		emission *= mix(1.0, 1.35, scream_band * scream_line_strength * active);
	}

	// 4. Cuantización de color / posterización
	if (color_quantization > 0.0) {
		float levels = 1.0 / color_quantization;
		col = floor(col * levels + 0.5) / levels;

		if (dither_strength > 0.0) {
			float d = grain(uv + vec2(t * 0.1, t * 0.2), t) - 0.5;
			col += d * dither_strength / levels;
		}

		emission = floor(emission * levels * 0.5 + 0.5) / (levels * 0.5);
	}

	// 5. Flicker aleatorio
	if (flicker_strength > 0.0) {
		float flick_a = sin(t * 30.0) * cos(t * 17.0) * 0.5 + 0.5;
		float flick_b = step(0.84, noise(vec2(floor(t * 18.0), 2.0)));
		float flick = mix(1.0, flick_a, flicker_strength);
		flick *= mix(1.0, 0.65, flick_b * flicker_strength * 0.7);

		emission *= flick;
		col *= mix(1.0, flick * 0.9 + 0.1, flicker_strength * 0.5);
	}

	// 6. Glow recortado
	emission = clamp(emission, 0.0, glow_clamp);

	// 7. Borde enfermo
	float edge = 1.0 - abs(tex.a - mask);
	col = mix(col, vec3(0.2, 0.0, 0.0), (1.0 - edge) * 0.3 * active);

	// 8. CD dropout: pequeños "apagones" aleatorios
	float dropout = step(0.965, noise(vec2(floor(t * 26.0), floor(uv.y * 40.0))));
	col *= mix(1.0, 0.72, dropout * cd_glitch_strength * 10.0 * active);
	emission *= mix(1.0, 0.55, dropout * cd_glitch_strength * 12.0 * active);

	// =========================
	// FINAL
	// =========================
	ALBEDO = col;
	EMISSION = emission;
	ALPHA = tex.a * active;
}