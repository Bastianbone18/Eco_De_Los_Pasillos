shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// ============================================================
// TEXTURA PRINCIPAL (fuego)
// ============================================================
uniform sampler2D fire_tex : source_color;

// ============================================================
// CONTROLES DE FUEGO
// ============================================================
uniform vec2 uv_scale = vec2(1.5, 1.2);
uniform float speed = 1.15;
uniform float intensity = 1.35;
uniform float alpha_strength = 0.85;

// ============================================================
// DISTORSIÓN
// ============================================================
uniform float distortion_strength = 0.14;
uniform float wave_strength = 0.22;
uniform float warp_speed = 1.8;

// ============================================================
// VÉRTICE (WOBBLE)
// ============================================================
uniform float vertex_wobble = 0.12;
uniform float vertex_speed = 2.4;
uniform float top_wobble_boost = 2.5;

// ============================================================
// PUNTA DE LLAMA (más irregular)
// ============================================================
uniform float flame_tip_height = 0.28;
uniform float flame_tip_density = 12.0;
uniform float flame_tip_speed = 2.9;
uniform float flame_tip_sharpness = 2.5;

// ============================================================
// COLORES (base terror)
// ============================================================
uniform vec3 color_base  : source_color = vec3(0.08, 0.01, 0.01); // casi negro
uniform vec3 color_mid   : source_color = vec3(0.35, 0.05, 0.05); // rojo oscuro
uniform vec3 color_hot   : source_color = vec3(0.75, 0.20, 0.10); // naranja quemado
uniform vec3 color_tip   : source_color = vec3(0.90, 0.55, 0.35); // crema ensangrentado

// ============================================================
// SANGRE EN LA BASE
// ============================================================
uniform float blood_amount = 0.65;       // intensidad de la sangre
uniform float blood_drip_speed = 1.2;    // velocidad del goteo
uniform vec3  blood_color : source_color = vec3(0.45, 0.05, 0.05);

// ============================================================
// HUMO (procedural, terrorífico)
// ============================================================
uniform float smoke_opacity = 0.55;
uniform float smoke_speed = 0.35;
uniform vec3  smoke_color = vec3(0.08, 0.07, 0.10); // azul-negro fantasmal

// ============================================================
// LATIDO ACELERADO (ritual frenético)
// ============================================================
uniform float pulse_speed = 2.8;          // latidos por segundo
uniform float pulse_strength = 0.45;      // qué tanto afecta alpha/emission
uniform float panic_intensity = 0.6;      // aumento de brillo en pico de latido

// ============================================================
// EFECTOS PS1 / TERROR
// ============================================================
uniform float flicker_strength = 0.18;
uniform float flicker_speed = 9.0;
uniform float edge_darkness = 0.70;
uniform float pixel_quantize = 0.02;
uniform float dither_strength = 0.04;

// ============================================================
// VÉRTICE: WOBBLE ORGÁNICO (llama + terror)
// ============================================================
void vertex() {
	float t = TIME * vertex_speed;
	float top_mask = smoothstep(0.2, 0.9, UV.y);
	
	float wobble_a = sin((VERTEX.y * 6.0) + (UV.x * 9.0) + t) * vertex_wobble;
	float wobble_b = cos((VERTEX.y * 8.5) + (UV.x * 13.0) + t * 1.5) * vertex_wobble * 0.7;
	
	float final_wobble_x = wobble_a * top_mask * top_wobble_boost;
	float final_wobble_z = wobble_b * top_mask * top_wobble_boost;
	
	VERTEX.x += final_wobble_x;
	VERTEX.z += final_wobble_z;
	
	// pequeña ondulación vertical
	VERTEX.y += sin((UV.x * 14.0) + t * 1.9) * 0.03 * top_mask;
}

// ============================================================
// FRAGMENT: FUEGO + SANGRE + HUMO + LATIDO ACELERADO
// ============================================================
void fragment() {
	// ---------- MUESTREO DE FUEGO ----------
	vec2 uv1 = UV * uv_scale;
	vec2 uv2 = UV * uv_scale;
	uv1.y -= TIME * speed;
	uv2.y -= TIME * (speed * 0.6);
	
	float n1 = texture(fire_tex, uv1).r;
	float n2 = texture(fire_tex, uv2).r;
	
	vec2 warped_uv = UV * uv_scale;
	warped_uv.x += (n1 - 0.5) * distortion_strength;
	warped_uv.x += sin((UV.y * 12.0) - TIME * warp_speed) * wave_strength * 0.1;
	warped_uv.y -= TIME * speed;
	
	vec4 tex = texture(fire_tex, warped_uv);
	float flame_mask = tex.r;
	float secondary = n2;
	
	// ---------- COLOR GRADIENTE (fuego) ----------
	vec3 col = mix(color_base, color_mid, smoothstep(0.08, 0.45, flame_mask));
	col = mix(col, color_hot, smoothstep(0.35, 0.78, flame_mask));
	col = mix(col, color_tip, smoothstep(0.72, 1.00, flame_mask) * smoothstep(0.55, 1.0, UV.y));
	
	// ---------- SANGRE EN LA BASE (goteo animado) ----------
	float blood_zone = 1.0 - smoothstep(0.0, 0.25, UV.y); // 0.0 a 0.25 de altura
	// Goteo: rayas verticales que se mueven hacia abajo
	float drip = fract(UV.x * 12.0 - TIME * blood_drip_speed);
	drip = step(0.85, drip) * (1.0 - smoothstep(0.0, 0.2, UV.y));
	float blood_mask = clamp(blood_zone * 0.8 + drip * 0.5, 0.0, 1.0);
	blood_mask *= blood_amount;
	col = mix(col, blood_color, blood_mask);
	
	// ---------- HUMO FANTASMAL (procedural) ----------
	vec2 smoke_uv = UV * vec2(1.8, 1.2);
	smoke_uv.y += TIME * smoke_speed;
	smoke_uv.x += sin(TIME * 0.5) * 0.05;
	float smoke_noise = fract(sin(smoke_uv.x * 15.0 + smoke_uv.y * 25.0) * 437.58);
	smoke_noise = smoothstep(0.3, 0.8, smoke_noise);
	smoke_noise *= (1.0 - smoothstep(0.4, 1.0, UV.y)) * smoke_opacity;
	col = mix(col, smoke_color, smoke_noise);
	
	// ---------- OSCURECIMIENTO DE BORDES (cilindro) ----------
	float edge_mask = 1.0 - abs(UV.x - 0.5) * 2.0;
	edge_mask = smoothstep(0.2, 0.9, edge_mask);
	col *= mix(edge_darkness, 1.0, edge_mask);
	
	// ---------- ALPHA DEL FUEGO ----------
	float alpha = flame_mask;
	alpha *= mix(0.7, 1.2, secondary);
	alpha *= alpha_strength;
	alpha *= smoothstep(0.04, 0.28, UV.y);
	
	// punta irregular
	float tip_noise_a = sin(UV.x * flame_tip_density + TIME * flame_tip_speed) * 0.5 + 0.5;
	float tip_noise_b = sin(UV.x * (flame_tip_density * 1.73) - TIME * (flame_tip_speed * 1.35)) * 0.5 + 0.5;
	float tip_noise_c = sin(UV.x * (flame_tip_density * 0.63) + TIME * (flame_tip_speed * 0.8)) * 0.5 + 0.5;
	float tip_mix = (tip_noise_a * 0.5) + (tip_noise_b * 0.35) + (tip_noise_c * 0.15);
	tip_mix = pow(tip_mix, flame_tip_sharpness);
	float tip_height = 1.0 - flame_tip_height * tip_mix;
	float top_shape = 1.0 - smoothstep(tip_height - 0.12, tip_height + 0.04, UV.y);
	alpha *= top_shape;
	
	// rotura de bordes
	float edge_breakup = sin(UV.x * 18.0 + TIME * 4.5) * 0.5 + 0.5;
	alpha *= mix(0.75, 1.12, edge_breakup);
	
	// ---------- LATIDO ACELERADO (ritual frenético) ----------
	float pulse = 0.8 + sin(TIME * pulse_speed) * pulse_strength;
	pulse += sin(TIME * (pulse_speed * 2.1)) * 0.15; // armónico para latido más agresivo
	pulse = clamp(pulse, 0.6, 1.3);
	alpha *= pulse;
	
	// parpadeo rápido adicional
	float flicker = 0.85 + sin(TIME * flicker_speed) * flicker_strength;
	flicker += sin(TIME * 2.3) * 0.05;
	alpha *= flicker;
	
	alpha = clamp(alpha, 0.0, 1.0);
	
	// ---------- ESTILO PS1 ----------
	col = floor(col / pixel_quantize) * pixel_quantize;
	float dither = fract(FRAGCOORD.x * FRAGCOORD.y * 0.5);
	col += (dither - 0.5) * dither_strength;
	
	// ---------- EMISSION (con latido que intensifica el brillo) ----------
	float panic_glow = 1.0 + (pulse - 0.8) * panic_intensity;
	vec3 emission_col = col * (1.5 + secondary * 1.1) * intensity * panic_glow;
	emission_col += blood_color * blood_mask * 1.2;  // sangre brillante
	
	ALBEDO = col;
	EMISSION = emission_col;
	ALPHA = alpha;
}