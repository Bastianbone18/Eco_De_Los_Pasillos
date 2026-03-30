shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

uniform float pulse_speed : hint_range(0.0, 12.0) = 3.5;
uniform float wobble_speed : hint_range(0.0, 12.0) = 2.8;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.2;
uniform float chroma_amount : hint_range(0.0, 0.08) = 0.018;

uniform float warp_strength : hint_range(0.0, 3.0) = 1.7;
uniform float noise_strength : hint_range(0.0, 2.0) = 0.65;
uniform float dirt_strength : hint_range(0.0, 2.0) = 0.75;
uniform float line_strength : hint_range(0.0, 1.0) = 0.32;
uniform float ghost_strength : hint_range(0.0, 1.0) = 0.42;
uniform float strobe_strength : hint_range(0.0, 1.0) = 0.28;
uniform float smear_strength : hint_range(0.0, 1.0) = 0.30;

uniform vec3 sick_tint = vec3(0.90, 0.98, 1.08);
uniform vec3 rot_tint  = vec3(0.92, 1.05, 0.90);
uniform vec3 dark_tint = vec3(0.05, 0.05, 0.05);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	float t = TIME;

	float s = saturate(strength);
	float pulse = sin(t * mix(1.8, pulse_speed * 3.0, s)) * 0.5 + 0.5;
	float pulse2 = sin(t * mix(2.6, pulse_speed * 4.8, s) + 1.2) * 0.5 + 0.5;
	float pulse_mix = mix(pulse, max(pulse, pulse2), 0.45);

	// =========================
	// DISTORSIÓN BASE
	// =========================
	vec2 d = uv - center;
	float r = length(d);
	float edge_fac = smoothstep(0.08, 0.95, r);

	float ang = (0.010 + 0.050 * s) * sin(t * wobble_speed + r * 10.0);
	float cs = cos(ang);
	float sn = sin(ang);
	mat2 rot = mat2(vec2(cs, -sn), vec2(sn, cs));
	d = rot * d;
	uv = center + d;

	float wob = (0.001 + 0.008 * s) * (0.25 + 0.75 * edge_fac);
	uv.x += sin((uv.y + t * wobble_speed) * 14.0) * wob;
	uv.y += cos((uv.x + t * wobble_speed * 0.85) * 10.0) * wob * 0.8;

	vec2 dd = uv - center;
	float rr = length(dd);
	uv += dd * (rr * rr) * (0.015 + 0.095 * s) * warp_strength;

	// =========================
	// JITTER / MICRO SALTO
	// =========================
	float jx = noise(uv * (260.0 + 700.0 * s) + vec2(t * 2.5, -t * 1.9));
	float jy = noise(uv.yx * (280.0 + 760.0 * s) + vec2(-t * 1.6, t * 2.2));
	vec2 jitter = (vec2(jx, jy) - 0.5);

	float st = sin(t * (10.0 + 36.0 * s)) * 0.5 + 0.5;
	float strobe = smoothstep(0.75, 1.0, st) * strobe_strength * s;

	uv += jitter * (0.0008 + 0.0060 * s) * (0.4 + 0.6 * strobe);

	// =========================
	// BLUR SUCIO
	// =========================
	float b = blur_amount * s * (0.0008 + 0.0032 * (0.2 + edge_fac));

	vec4 col = texture(screen_tex, uv) * 0.24;
	col += texture(screen_tex, uv + vec2( b, 0.0)) * 0.12;
	col += texture(screen_tex, uv + vec2(-b, 0.0)) * 0.12;
	col += texture(screen_tex, uv + vec2(0.0,  b)) * 0.12;
	col += texture(screen_tex, uv + vec2(0.0, -b)) * 0.12;
	col += texture(screen_tex, uv + vec2( b,  b)) * 0.07;
	col += texture(screen_tex, uv + vec2(-b,  b)) * 0.07;
	col += texture(screen_tex, uv + vec2( b, -b)) * 0.07;
	col += texture(screen_tex, uv + vec2(-b, -b)) * 0.07;

	// =========================
	// CHROMA FUERTE
	// =========================
	vec2 ca = (uv - center) * chroma_amount * s * (0.45 + 1.2 * edge_fac);
	float rch = texture(screen_tex, uv + ca).r;
	float gch = texture(screen_tex, uv).g;
	float bch = texture(screen_tex, uv - ca).b;
	vec3 chroma_col = vec3(rch, gch, bch);

	col.rgb = mix(col.rgb, chroma_col, (0.45 + 0.45 * edge_fac) * s);

	// =========================
	// GHOSTING DOBLE
	// =========================
	vec2 ghost_off1 = vec2(0.004, -0.002) * ghost_strength * s;
	vec2 ghost_off2 = vec2(-0.006, 0.003) * ghost_strength * s;

	vec3 ghost1 = texture(screen_tex, uv + ghost_off1).rgb;
	vec3 ghost2 = texture(screen_tex, uv + ghost_off2).rgb;

	col.rgb = mix(col.rgb, ghost1, 0.18 * s);
	col.rgb = mix(col.rgb, ghost2, 0.14 * s);

	// =========================
	// SMEAR HORIZONTAL
	// =========================
	float smear = smear_strength * s * (0.25 + 0.75 * pulse_mix);
	vec3 smear_col = vec3(0.0);
	smear_col += texture(screen_tex, uv + vec2( 0.003 * smear, 0.0)).rgb * 0.30;
	smear_col += texture(screen_tex, uv + vec2(-0.004 * smear, 0.0)).rgb * 0.24;
	smear_col += texture(screen_tex, uv + vec2( 0.007 * smear, 0.0)).rgb * 0.16;
	col.rgb = mix(col.rgb, smear_col, 0.16 * s);

	// =========================
	// RUIDO GRUESO + FINO
	// =========================
	float fine_grain = noise(SCREEN_UV * (900.0 + 1800.0 * s) + vec2(t * 2.4, t * 1.8)) - 0.5;
	float coarse_grain = noise(SCREEN_UV * (140.0 + 280.0 * s) + vec2(-t * 0.9, t * 0.7)) - 0.5;
	col.rgb += fine_grain * (0.020 + 0.10 * s) * noise_strength;
	col.rgb += coarse_grain * (0.010 + 0.060 * s) * noise_strength;

	// =========================
	// MANCHAS / SUCIEDAD
	// =========================
	float dirt = fbm(SCREEN_UV * vec2(4.0, 6.8) + vec2(t * 0.05, -t * 0.03));
	float dirt_mask = smoothstep(0.54, 0.90, dirt) * (0.2 + 0.8 * edge_fac);
	col.rgb = mix(col.rgb, col.rgb * 0.52, dirt_mask * dirt_strength * s);

	float blotch = fbm(SCREEN_UV * vec2(1.8, 3.2) + vec2(-t * 0.08, t * 0.05));
	float blotch_mask = smoothstep(0.60, 0.96, blotch);
	col.rgb = mix(col.rgb, col.rgb * vec3(0.38, 0.40, 0.42), blotch_mask * 0.28 * s);

	// =========================
	// LÍNEAS / VHS / TEARING
	// =========================
	float lines = sin((SCREEN_UV.y + t * 0.6) * (260.0 + 90.0 * s)) * 0.5 + 0.5;
	float line_mask = smoothstep(0.42, 1.0, lines) * line_strength * (0.15 + 0.85 * s);
	col.rgb *= 1.0 - line_mask * 0.12;

	float scan_band = smoothstep(0.93, 1.0, sin((SCREEN_UV.y * 18.0) - t * 5.0) * 0.5 + 0.5);
	col.rgb -= scan_band * 0.05 * s;

	float tear = smoothstep(0.982, 1.0, noise(vec2(t * 0.8, floor(SCREEN_UV.y * 22.0))));
	col.rgb = mix(col.rgb, texture(screen_tex, uv + vec2(0.012 * s, 0.0)).rgb, tear * 0.16 * s);

	// =========================
	// TINTE ENFERMO / ENSUCIADO
	// =========================
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float desat = 0.08 + 0.42 * s;
	col.rgb = mix(col.rgb, vec3(luma), desat);

	col.rgb = mix(col.rgb, col.rgb * sick_tint, 0.18 * s);
	col.rgb = mix(col.rgb, col.rgb * rot_tint, 0.12 * s);

	// Oscurecimiento leve sin túnel
	float subtle_dark = (0.04 + 0.16 * s) * edge_fac;
	col.rgb *= 1.0 - subtle_dark;
	col.rgb = mix(col.rgb, dark_tint, 0.10 * s * edge_fac);

	// Pulsos corruptos
	col.rgb *= 1.0 - (0.04 * pulse_mix * s);
	col.rgb += fine_grain * 0.03 * strobe;

	COLOR = vec4(col.rgb, 1.0);
}