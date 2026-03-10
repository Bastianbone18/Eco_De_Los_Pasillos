shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

uniform float pulse_speed : hint_range(0.0, 12.0) = 4.2;
uniform float wobble_speed : hint_range(0.0, 12.0) = 2.2;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.4;
uniform float chroma_amount : hint_range(0.0, 0.03) = 0.011;

uniform float edge_darkness : hint_range(0.0, 2.5) = 2.15;
uniform float edge_close : hint_range(0.0, 1.0) = 0.86;
uniform float center_softness : hint_range(0.0, 1.0) = 0.18;

uniform float edge_warp : hint_range(0.0, 2.0) = 1.45;

// ✅ Nuevo: tamaño del centro visible (más pequeño = más claustrofobia)
uniform float center_radius : hint_range(0.05, 0.45) = 0.17;

// ✅ Nuevo: “shock” de pánico (micro strobe + jitter). 0 = off
uniform float panic_shock : hint_range(0.0, 1.0) = 0.85;


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

float saturate(float x) { return clamp(x, 0.0, 1.0); }

// Remap por fases: lento -> medio -> colapso (SIN tocar tu código)
float panic_curve(float s) {
	s = saturate(s);

	// Fase 1 (0..0.55): casi nada
	float a = pow(s / 0.55, 3.3);               // ultra lento
	a = saturate(a) * 0.30;

	// Fase 2 (0.55..0.85): empieza a sentirse
	float b = pow((s - 0.55) / 0.30, 1.55);
	b = saturate(b);
	float mid = 0.30 + b * 0.40;                // 0.30..0.70

	// Fase 3 (0.85..1.0): colapso brutal
	float c = pow((s - 0.85) / 0.15, 0.75);     // sube rapidísimo
	c = saturate(c);
	float end = 0.70 + c * 0.30;                // 0.70..1.0

	// Mezcla por tramos
	float m1 = step(0.55, s);
	float m2 = step(0.85, s);

	float outv = mix(a, mid, m1);
	outv = mix(outv, end, m2);
	return saturate(outv);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	float t = TIME;

	float s = saturate(strength);

	// ✅ Progresión “ataque de pánico” aunque strength sea lineal
	float prog = panic_curve(s);

	vec2 d0 = uv - center;
	float r0 = length(d0);
	float per = smoothstep(0.10, 0.88, r0);

	// =========================
	// PALPITACIONES QUE ACELERAN
	// =========================
	// base -> extremo (mientras más prog, más rápido late)
	float bpm = mix(pulse_speed * 0.50, pulse_speed * 3.6, prog);

	float p1 = sin(t * bpm) * 0.5 + 0.5;
	float p2 = sin(t * (bpm * 1.90 + 0.8)) * 0.5 + 0.5;

	// “lub-dub” más fuerte al final
	float dub = sin(t * (bpm * 2.08 + 2.4)) * 0.5 + 0.5;
	float heartbeat = mix(mix(p1, p2, 0.62), max(p2, dub), 0.45 * prog);

	// respiración: al final se siente “cortada”
	float breath_rate = mix(0.55, 1.85, prog);
	float breath = sin(t * breath_rate) * 0.5 + 0.5;

	// =========================
	// OPRESIÓN/ZOOM (latidos visibles)
	// =========================
	float zoom = 1.0
		+ (0.006 * prog) * (0.25 + 0.75 * breath)
		+ (0.022 * prog) * (heartbeat - 0.5);

	uv = (uv - center) / zoom + center;

	// Recalc
	vec2 d = uv - center;

	// =========================
	// SWIRL / MAREO
	// =========================
	float swirl = (0.55 + 1.90 * heartbeat) * prog * per * 0.016;
	float ang = swirl * (0.50 + 0.50 * sin(t * wobble_speed));
	float cs = cos(ang);
	float sn = sin(ang);
	mat2 rot = mat2(vec2(cs, -sn), vec2(sn, cs));
	d = rot * d;
	uv = center + d;

	// =========================
	// SHOCK: jitter + micro strobe (solo final)
	// =========================
	float shock_gate = smoothstep(0.62, 1.0, prog) * panic_shock;

	// strobe suave (evita parpadeo violento)
	float st = sin(t * (9.0 + 42.0 * prog)) * 0.5 + 0.5;
	float strobe = smoothstep(0.72, 1.0, st) * shock_gate;

	float jn = noise(uv * (150.0 + 650.0 * prog) + vec2(t * 2.2, -t * 1.9));
	vec2 jitter = (vec2(jn, noise(uv * 233.0 + vec2(t * 1.3, t))) - 0.5);

	uv += jitter * (0.0009 + 0.0058 * prog) * per * (0.30 + 0.70 * strobe);

	// =========================
	// WOBBLE periférico
	// =========================
	float wobble_amp = (0.0014 + 0.0062 * prog) * per;
	uv.x += sin((uv.y + t * wobble_speed) * 10.0) * wobble_amp;
	uv.y += cos((uv.x + t * wobble_speed) * 8.0)  * wobble_amp * 0.85;

	// Warp radial (opresión)
	vec2 dd = uv - center;
	float rr = length(dd);

	float warp = (0.028 + 0.090 * prog) * per * edge_warp * (0.55 + 0.45 * heartbeat);
	uv += dd * (rr * rr) * warp;

	// =========================
	// BLUR
	// =========================
	float b = blur_amount * prog * (0.0008 + 0.0032 * per);

	vec4 col = texture(screen_tex, uv) * 0.24;
	col += texture(screen_tex, uv + vec2( b, 0.0)) * 0.11;
	col += texture(screen_tex, uv + vec2(-b, 0.0)) * 0.11;
	col += texture(screen_tex, uv + vec2(0.0,  b)) * 0.11;
	col += texture(screen_tex, uv + vec2(0.0, -b)) * 0.11;
	col += texture(screen_tex, uv + vec2( b,  b)) * 0.08;
	col += texture(screen_tex, uv + vec2(-b,  b)) * 0.08;
	col += texture(screen_tex, uv + vec2( b, -b)) * 0.08;
	col += texture(screen_tex, uv + vec2(-b, -b)) * 0.08;

	// =========================
	// CHROMA (sube fuerte al final)
	// =========================
	vec2 ca = (uv - center) * chroma_amount * prog * (0.22 + 1.45 * per);
	float rch = texture(screen_tex, uv + ca).r;
	float gch = texture(screen_tex, uv).g;
	float bch = texture(screen_tex, uv - ca).b;
	col.rgb = mix(col.rgb, vec3(rch, gch, bch), (0.45 + 0.55 * per) * prog);

	// =========================
	// GRAIN + color “enfermo”
	// =========================
	float g = noise(SCREEN_UV * (760.0 + 1400.0 * prog) + vec2(t * 2.3, t * 1.6));
	float grain = (g - 0.5) * (0.012 + 0.090 * prog) * (0.20 + 0.80 * per);
	col.rgb += grain;

	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float desat = (0.08 + 0.76 * prog) * per;
	col.rgb = mix(col.rgb, vec3(luma), desat);

	// frío + verdoso (pánico/sangre se va)
	col.rgb = mix(col.rgb, col.rgb * vec3(0.90, 0.98, 1.12), 0.22 * prog * per);
	col.rgb = mix(col.rgb, col.rgb * vec3(0.92, 1.08, 0.92), 0.10 * prog * per);

	// oscurecimiento tipo “flash” (micro strobe)
	col.rgb *= (1.0 - 0.08 * strobe * prog * per);

	// =========================
	// VIGNETTE/TÚNEL: MÁS LENTO AL INICIO + CÍRCULO MÁS PEQUEÑO
	// =========================
	// ✅ cierre con curva extra lenta al inicio
	float close_amt = edge_close * pow(s, 4.2);

	// ✅ centro más pequeño desde temprano; se encoge más con close_amt
	float inner = mix(center_radius * 1.05, center_radius * 0.62, close_amt);

	// outer se mueve de “amplio” a “claustro”
	float outer = mix(0.88, 0.42, close_amt);

	inner = max(inner, 0.035);
	outer = max(outer, inner + 0.12);

	// suavidad: inicio suave, final duro
	float soft = mix(center_softness + 0.18, center_softness * 0.40, prog);

	float tunnel = smoothstep(inner + soft, outer, rr);

	float dark = tunnel * edge_darkness * prog;

	// golpes nerviosos (NO cambia forma del gradiente)
	float hit = (heartbeat - 0.5) * 2.0; // -1..1
	dark *= (1.0 + 0.14 * hit * shock_gate);

	// más “colapso” al final
	dark += 0.06 * strobe * per * prog;

	dark = clamp(dark, 0.0, 1.0);

	col.rgb *= (1.0 - dark);
	col.rgb = mix(col.rgb, vec3(0.0), dark);

	COLOR = col;
}
