shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// ============================================================
// TEXTURAS
// ============================================================
uniform sampler2D fire_tex  : source_color;
uniform sampler2D souls_tex : source_color;
uniform sampler2D flesh_tex : source_color;

// ============================================================
// UV / MOVIMIENTO BASE
// ============================================================
uniform vec2 uv_scale = vec2(1.45, 1.2);
uniform float speed = 1.0;

// ============================================================
// ALMAS
// ============================================================
uniform float souls_speed = 0.28;
uniform float souls_strength = 0.9;
uniform float souls_distortion = 0.05;
uniform vec2 souls_scale = vec2(1.0, 1.8);

// colores almas
uniform vec3 souls_color_a : source_color = vec3(0.78, 0.78, 0.82);
uniform vec3 souls_color_b : source_color = vec3(0.45, 0.45, 0.52);
uniform vec3 souls_color_c : source_color = vec3(0.20, 0.18, 0.22);

// ============================================================
// CARNE / MEMBRANA
// ============================================================
uniform vec2 flesh_scale = vec2(1.15, 1.15);
uniform float flesh_strength = 0.7;
uniform float flesh_distortion = 0.06;

// colores carne
uniform vec3 flesh_color_a : source_color = vec3(0.16, 0.01, 0.01);
uniform vec3 flesh_color_b : source_color = vec3(0.34, 0.02, 0.03);
uniform vec3 flesh_color_c : source_color = vec3(0.58, 0.10, 0.08);

// ============================================================
// PALETA BASE PORTAL
// ============================================================
uniform vec3 color_base : source_color = vec3(0.03, 0.005, 0.005);
uniform vec3 color_mid  : source_color = vec3(0.20, 0.01, 0.02);
uniform vec3 color_hot  : source_color = vec3(0.62, 0.12, 0.08);
uniform vec3 color_tip  : source_color = vec3(0.75, 0.22, 0.22);

// ============================================================
// PALPITACIÓN
// ============================================================
uniform float pulse_speed = 1.35;
uniform float pulse_strength = 0.10;   // MÁS SUAVE
uniform float pulse_emission_boost = 0.18;
uniform float pulse_alpha_boost = 0.06;

// color del palpitar
uniform vec3 pulse_color_a : source_color = vec3(0.45, 0.05, 0.05);
uniform vec3 pulse_color_b : source_color = vec3(0.20, 0.01, 0.01);

// ============================================================
// VÉRTEX WAVE (cilindro vivo)
// ============================================================
uniform float wave_strength = 0.10;
uniform float wave_speed = 1.6;
uniform float wave_frequency = 5.0;
uniform float vertical_wave_strength = 0.035;
uniform float top_influence = 1.8;

// ============================================================
// DESVANECIDO DEL BORDE SUPERIOR
// ============================================================
uniform float top_fade_start = 0.72;
uniform float top_fade_end = 1.0;
uniform float top_edge_softness = 1.0;

// ============================================================
// GENERALES
// ============================================================
uniform float alpha_strength = 0.88;
uniform float intensity = 1.35;
uniform float edge_darkness = 0.78;

// ============================================================
// LATIDO SUAVE TIPO ORGÁNICO
// ============================================================
float soft_pulse(float t) {
	float a = sin(t) * 0.5 + 0.5;
	float b = sin(t * 2.0 + 0.65) * 0.5 + 0.5;
	float c = mix(a, b, 0.35);
	return smoothstep(0.35, 0.9, c);
}

// ============================================================
// VÉRTEX
// ============================================================
void vertex() {
	float t = TIME * wave_speed;

	float hmask = smoothstep(0.05, 1.0, UV.y);
	hmask = pow(hmask, top_influence);

	float wave1 = sin(UV.y * wave_frequency + t);
	float wave2 = cos(UV.x * 6.0 - t * 1.2) * 0.4;
	float final_wave = (wave1 + wave2) * wave_strength * hmask;

	// expansión radial, ideal para cilindro
	VERTEX.x += NORMAL.x * final_wave;
	VERTEX.z += NORMAL.z * final_wave;

	// onda vertical suave
	float vwave = sin(UV.y * 7.0 + UV.x * 4.0 + t * 1.3);
	VERTEX.y += vwave * vertical_wave_strength * hmask;
}

// ============================================================
// FRAGMENT
// ============================================================
void fragment() {
	float t = TIME;

	// --------------------------------------------------------
	// PULSE
	// --------------------------------------------------------
	float pulse = soft_pulse(t * pulse_speed);
	float pulse_mix = 1.0 + pulse * pulse_strength;

	// --------------------------------------------------------
	// UV BASE
	// --------------------------------------------------------
	vec2 uv = UV * uv_scale;
	uv.y -= t * speed;

	// --------------------------------------------------------
	// ALMAS (suben)
	// --------------------------------------------------------
	vec2 souls_uv = UV * souls_scale;
	souls_uv.y += t * souls_speed;

	float souls_tex_val = texture(souls_tex, souls_uv).r;
	float souls_mask = smoothstep(0.18, 0.95, souls_tex_val);

	uv.x += (souls_tex_val - 0.5) * souls_distortion;

	vec3 souls_col = mix(souls_color_c, souls_color_b, smoothstep(0.18, 0.55, souls_tex_val));
	souls_col = mix(souls_col, souls_color_a, smoothstep(0.55, 1.0, souls_tex_val));

	// --------------------------------------------------------
	// CARNE / MEMBRANA
	// --------------------------------------------------------
	vec2 flesh_uv = UV * flesh_scale;
	float flesh_tex_val = texture(flesh_tex, flesh_uv).r;
	float flesh_mask = smoothstep(0.15, 0.95, flesh_tex_val);

	uv += (flesh_tex_val - 0.5) * flesh_distortion * pulse_mix * flesh_strength;

	vec3 flesh_col = mix(flesh_color_a, flesh_color_b, smoothstep(0.12, 0.55, flesh_tex_val));
	flesh_col = mix(flesh_col, flesh_color_c, smoothstep(0.55, 1.0, flesh_tex_val));

	// --------------------------------------------------------
	// SAMPLE FINAL
	// --------------------------------------------------------
	float flame_mask = texture(fire_tex, uv).r;

	// --------------------------------------------------------
	// COLOR BASE PORTAL
	// --------------------------------------------------------
	vec3 col = mix(color_base, color_mid, smoothstep(0.06, 0.35, flame_mask));
	col = mix(col, color_hot, smoothstep(0.30, 0.72, flame_mask));
	col = mix(col, color_tip, smoothstep(0.72, 1.0, flame_mask) * smoothstep(0.45, 1.0, UV.y));

	// integrar carne
	col = mix(col, flesh_col, flesh_mask * 0.42);

	// integrar almas
	col += souls_col * souls_mask * souls_strength * 0.33;

	// color de pulso, MUY sutil
	vec3 pulse_col = mix(pulse_color_b, pulse_color_a, pulse);
	col += pulse_col * pulse * 0.10;

	// --------------------------------------------------------
	// OSCURECIMIENTO CILÍNDRICO LATERAL
	// --------------------------------------------------------
	float edge_mask = 1.0 - abs(UV.x - 0.5) * 2.0;
	edge_mask = smoothstep(0.12, 0.92, edge_mask);
	col *= mix(edge_darkness, 1.0, edge_mask);

	// --------------------------------------------------------
	// ALPHA BASE
	// --------------------------------------------------------
	float alpha = flame_mask * alpha_strength;
	alpha *= mix(0.92, 1.03, flesh_mask);
	alpha *= 0.96 + pulse * pulse_alpha_boost;

	// --------------------------------------------------------
	// DESVANECIDO SOLO DEL BORDE SUPERIOR
	// Esto hace que la tapa superior no se lea tan plana
	// --------------------------------------------------------
	float top_fade = 1.0 - smoothstep(top_fade_start, top_fade_end, UV.y);
	top_fade = pow(top_fade, top_edge_softness);
	alpha *= top_fade;

	// --------------------------------------------------------
	// EMISSION
	// --------------------------------------------------------
	vec3 emission = col * intensity;
	emission += souls_col * souls_mask * souls_strength * 0.45;
	emission += flesh_col * flesh_mask * 0.10;
	emission *= 1.0 + pulse * pulse_emission_boost;

	ALBEDO = col;
	EMISSION = emission;
	ALPHA = clamp(alpha, 0.0, 1.0);
}