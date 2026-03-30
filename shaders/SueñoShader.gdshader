shader_type canvas_item;

// ==================================================
// CONTROL PRINCIPAL
// ==================================================
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// ==================================================
// 1) RESPIRACIÓN IRREGULAR
// ==================================================
uniform float breathe_strength : hint_range(0.0, 0.1) = 0.012;
uniform float breathe_speed : hint_range(0.0, 10.0) = 0.85;

// ==================================================
// 2) COMPRESIÓN HACIA EL CENTRO
// ==================================================
uniform float pull_strength : hint_range(0.0, 0.1) = 0.016;
uniform float center_falloff : hint_range(0.1, 4.0) = 1.55;

// ==================================================
// 3) MICRO TORSIÓN ASIMÉTRICA
// ==================================================
uniform float twist_strength : hint_range(0.0, 0.05) = 0.0035;

// ==================================================
// 4) ABERRACIÓN CROMÁTICA MUY SUTIL
// ==================================================
uniform float chroma_strength : hint_range(0.0, 0.02) = 0.0009;

// ==================================================
// 5) PIXEL SHIFT PS1 SUAVE
// ==================================================
uniform float pixel_shift_strength : hint_range(0.0, 8.0) = 0.8;
uniform float base_resolution : hint_range(64.0, 1024.0) = 256.0;

// ==================================================
// 6) JITTER / INESTABILIDAD
// ==================================================
uniform float jitter_strength : hint_range(0.0, 0.01) = 0.00045;
uniform float jitter_speed : hint_range(0.0, 10.0) = 1.15;

// ==================================================
// 7) GHOST MUY LEVE
// ==================================================
uniform float ghost_strength : hint_range(0.0, 0.2) = 0.018;

// ==================================================
// 8) FLICKER CASI IMPERCEPTIBLE
// ==================================================
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.018;

// ==================================================
// 9) DRAIN / DESATURACIÓN PESADILLA
// ==================================================
uniform float desaturate_strength : hint_range(0.0, 1.0) = 0.38;
uniform float darken_strength : hint_range(0.0, 1.0) = 0.10;

// ==================================================
// 10) PRESENCIA / SOMBRA SUTIL
// ==================================================
uniform float shadow_strength : hint_range(0.0, 0.2) = 0.035;
uniform float shadow_drift : hint_range(0.0, 0.1) = 0.018;

// ==================================================
// 11) VIÑETA Y CENTRO PROFUNDO
// ==================================================
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.10;
uniform float center_depth_strength : hint_range(0.0, 1.0) = 0.14;


// --------------------------------------------------
// Ruido simple
// --------------------------------------------------
float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float t = TIME;

	// ==================================================
	// CURVAS DE PROGRESO
	// ==================================================
	float p1 = smoothstep(0.0, 1.0, progress);
	float p2 = p1 * p1;
	float p3 = p2 * p1;
	float p4 = p2 * p2; // entra todavía más tarde

	// ==================================================
	// 1) RESPIRACIÓN IRREGULAR
	// ==================================================
	float breath = sin(t * breathe_speed + sin(t * 0.7) * 0.8);
	breath += sin(t * 1.3 + 2.0) * 0.3;
	breath = breath * 0.5 + 0.5;

	float breathe_amount = breathe_strength * p2 * (0.25 + breath * 0.75);

	vec2 warped_uv = (uv - center) * (1.0 - breathe_amount) + center;

	// Micro deriva del plano: sensación de inestabilidad subconsciente
	warped_uv += vec2(
		sin(t * 0.6) * 0.0010 * p2,
		cos(t * 0.5) * 0.0008 * p2
	);

	// ==================================================
	// RECÁLCULO DIRECCIÓN / DISTANCIA
	// ==================================================
	vec2 dir = warped_uv - center;
	float dist = length(dir);
	vec2 n = dist > 0.0001 ? dir / dist : vec2(0.0);

	float center_mask = pow(max(0.0, 1.0 - dist * 1.7), center_falloff);
	float edge_mask = 1.0 - center_mask;

	// ==================================================
	// 2) COMPRESIÓN HACIA EL CENTRO
	// ==================================================
	float pull = pull_strength * p3 * (0.20 + center_mask * 0.80);
	warped_uv -= n * pull;

	// ==================================================
	// 3) MICRO TORSIÓN ASIMÉTRICA
	// No espiral obvia. Apenas una tensión lateral viva.
	// ==================================================
	float twist = sin(t * 1.05 + dist * 13.0) * twist_strength * p2 * center_mask;
	vec2 tangent = vec2(-n.y, n.x);
	warped_uv += tangent * twist;

	// ==================================================
	// 4) PIXEL SHIFT PS1 SUAVE
	// ==================================================
	float snap_scale = base_resolution / max(pixel_shift_strength, 0.0001);
	vec2 snapped_uv = floor(warped_uv * snap_scale) / snap_scale;
	warped_uv = mix(warped_uv, snapped_uv, p2 * 0.22);

	// ==================================================
	// 5) JITTER MÍNIMO
	// ==================================================
	float jx = sin(t * jitter_speed + uv.y * 10.0) * jitter_strength * p2;
	float jy = cos(t * (jitter_speed * 0.91) + uv.x * 8.0) * jitter_strength * p2;
	warped_uv += vec2(jx, jy);

	// ==================================================
	// 6) SAMPLE BASE + GHOST LEVE
	// ==================================================
	vec4 base_col = texture(TEXTURE, warped_uv);

	vec2 ghost_offset = vec2(0.0014, 0.0009) * (0.8 + sin(t * 1.9) * 0.2) * p2;
	vec4 ghost_col = texture(TEXTURE, warped_uv + ghost_offset);

	vec4 col = mix(base_col, ghost_col, ghost_strength * p2);

	// ==================================================
	// 7) ABERRACIÓN CROMÁTICA MUY SUTIL
	// ==================================================
	vec2 chroma_dir = n * chroma_strength * p2 * (0.35 + edge_mask * 0.65);

	float rr = texture(TEXTURE, warped_uv + chroma_dir).r;
	float gg = texture(TEXTURE, warped_uv).g;
	float bb = texture(TEXTURE, warped_uv - chroma_dir).b;

	vec4 chroma_col = vec4(rr, gg, bb, col.a);
	col.rgb = mix(col.rgb, chroma_col.rgb, 0.35 * p2);

	// ==================================================
	// 8) DESATURACIÓN / DRAIN
	// ==================================================
	vec3 gray = vec3(dot(col.rgb, vec3(0.299, 0.587, 0.114)));
	col.rgb = mix(col.rgb, gray, desaturate_strength * p2);

	// Oscurecimiento general muy leve
	col.rgb *= 1.0 - (darken_strength * p2);

	// ==================================================
	// 9) PRESENCIA / SOMBRA SUTIL
	// ==================================================
	vec2 shadow_uv = uv;
	shadow_uv += vec2(
		sin(t * 0.37) * shadow_drift,
		cos(t * 0.31) * shadow_drift * 0.8
	);

	float shadow_noise = random(floor(shadow_uv * 4.0));
	shadow_noise = smoothstep(0.58, 0.82, shadow_noise);

	// Más visible en zonas intermedias que en bordes extremos
	float shadow_mask = shadow_noise * shadow_strength * p3 * (0.4 + center_mask * 0.6);
	col.rgb *= 1.0 - shadow_mask * 0.45;

	// ==================================================
	// 10) CENTRO PROFUNDO
	// Hace que el centro "pese" un poco más.
	// ==================================================
	float center_dark = 1.0 - smoothstep(0.0, 0.42, dist);
	col.rgb *= 1.0 - (center_dark * center_depth_strength * p3);

	// ==================================================
	// 11) VIÑETA SUAVE
	// ==================================================
	float vig = smoothstep(0.98, 0.26, dist);
	col.rgb *= mix(1.0, vig, vignette_strength * p2);

	// ==================================================
	// 12) FLICKER CASI IMPERCEPTIBLE
	// ==================================================
	float flicker = sin(t * 7.0) * sin(t * 11.3 + 0.6);
	flicker = flicker * 0.5 + 0.5;
	col.rgb *= 1.0 - (flicker * flicker_strength * p4 * 0.18);

	// Mantener alpha original
	col.a = texture(TEXTURE, warped_uv).a;

	COLOR = col;
}