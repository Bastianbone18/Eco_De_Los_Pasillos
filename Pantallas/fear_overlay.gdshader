shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// 0..1 (desde script)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Control general
uniform float dead_zone : hint_range(0.0, 0.5) = 0.18;      // lejos = 0 real
uniform float max_alpha : hint_range(0.0, 0.85) = 0.28;     // tope (NO exagerado)
uniform float base_pulse_speed : hint_range(0.0, 8.0) = 0.8;
uniform float max_pulse_speed  : hint_range(0.0, 24.0) = 8.5;

// Vignette
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.10;
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.24;
uniform float vignette_outer : hint_range(0.0, 1.5) = 0.96;

// Extra tensión
uniform float breath_amount : hint_range(0.0, 1.0) = 0.32; // “respiración”
uniform float jitter_amount : hint_range(0.0, 1.0) = 0.16; // micro vibración bordes

// Color “maldito” (rojo apagado + verdoso enfermizo)
uniform float sick_tint : hint_range(0.0, 1.0) = 0.35;      // cuánto verdoso entra al final
uniform float black_crush : hint_range(0.0, 1.0) = 0.18;    // oscurece sin “sangre”

// =========================
// ✅ NUEVO: DISTORSIÓN PANTALLA (sube con terror)
// =========================
uniform float distortion_amount : hint_range(0.0, 2.0) = 1.15;     // fuerza general
uniform float distortion_wobble_speed : hint_range(0.0, 12.0) = 2.25;
uniform float distortion_swirl : hint_range(0.0, 2.0) = 1.05;      // “mareo” radial
uniform float blur_amount : hint_range(0.0, 8.0) = 1.65;           // blur leve (no exagerado)
uniform float chroma_amount : hint_range(0.0, 0.03) = 0.009;       // aberración cromática sutil

float saturate(float x) { return clamp(x, 0.0, 1.0); }

float remap_deadzone(float x, float dz){
	return saturate((x - dz) / max(0.0001, (1.0 - dz)));
}

// Curva ultra lenta al inicio
float fear_curve(float s){
	float a = pow(s, 2.8);
	a = mix(a, pow(s, 4.2), smoothstep(0.0, 0.6, s));
	return saturate(a);
}

// Hash barato para jitter
float hash(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Noise suave
float noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment(){
	vec2 suv = SCREEN_UV; // uv para samplear pantalla
	vec2 uv = UV;         // uv del overlay (para el borde/vignette)
	float t = TIME;

	// 1) Intensidad con zona muerta real + curva lenta
	float s0 = saturate(intensity);
	float s1 = remap_deadzone(s0, dead_zone);
	float s  = fear_curve(s1);

	// Gate: lejos = apagado total
	float gate = step(0.0005, s);

	// 2) Vignette base (más claustro en bordes)
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float edge = smoothstep(vignette_inner, vignette_outer, r);
	edge = pow(edge, 1.35) * vignette_strength;

	// 3) Pulso + doble latido (lub-dub) + respiración
	float spd = mix(base_pulse_speed, max_pulse_speed, s);

	float p1 = 0.5 + 0.5 * sin(t * spd);
	float p2 = 0.5 + 0.5 * sin(t * (spd * 1.85 + 1.2)); // segundo golpe
	float heartbeat = mix(p1, max(p1, p2), 0.55 * s);

	float breath_spd = mix(0.45, 1.8, s);
	float breath = 0.5 + 0.5 * sin(t * breath_spd);

	// 4) Micro jitter overlay (solo bordes)
	float hn = hash(uv * (80.0 + 220.0 * s) + t);
	float j = (hn - 0.5) * (0.0018 + 0.0055 * s) * jitter_amount * edge;
	uv += vec2(j, -j * 0.7);

	// =========================
	// ✅ DISTORSIÓN DE PANTALLA (suv)
	// =========================
	vec2 center = vec2(0.5);
	vec2 d0 = suv - center;
	float rr = length(d0);

	// Periferia pesa más (claustro)
	float per = smoothstep(0.10, 0.92, rr);

	// Fuerza final: depende de terror + borde + pulso
	float ds = distortion_amount * s * gate;
	ds *= (0.35 + 0.65 * per);
	ds *= (0.82 + 0.18 * heartbeat);

	// Wobble (ondulación)
	float wob_amp = (0.0009 + 0.0048 * s) * ds;
	suv.x += sin((suv.y + t * distortion_wobble_speed) * 11.0) * wob_amp;
	suv.y += cos((suv.x + t * distortion_wobble_speed) * 9.0)  * wob_amp * 0.85;

	// Swirl radial (mareo)
	float swirl = distortion_swirl * ds * per * (0.006 + 0.012 * s);
	float ang = swirl * (0.55 + 0.45 * sin(t * (0.9 + 2.1 * s)));
	float cs = cos(ang);
	float sn = sin(ang);
	mat2 rot = mat2(vec2(cs, -sn), vec2(sn, cs));
	vec2 d = rot * d0;
	suv = center + d;

	// Micro jitter de pantalla (ruido) más hacia el final
	float n1 = noise(suv * (180.0 + 720.0 * s) + vec2(t * 2.1, -t * 1.7));
	vec2 jit = (vec2(n1, noise(suv * 260.0 + vec2(t * 1.2, t))) - 0.5);
	suv += jit * (0.00035 + 0.0027 * s) * ds;

	// Clamp suave para evitar sampling fuera (artefactos)
	suv = clamp(suv, vec2(0.001), vec2(0.999));

	// =========================
	// Sample pantalla con blur leve + chroma sutil
	// =========================
	float b = blur_amount * ds * (0.0006 + 0.0026 * per);

	// blur 9 taps (ligero)
	vec4 sc = texture(screen_tex, suv) * 0.24;
	sc += texture(screen_tex, suv + vec2( b, 0.0)) * 0.11;
	sc += texture(screen_tex, suv + vec2(-b, 0.0)) * 0.11;
	sc += texture(screen_tex, suv + vec2(0.0,  b)) * 0.11;
	sc += texture(screen_tex, suv + vec2(0.0, -b)) * 0.11;
	sc += texture(screen_tex, suv + vec2( b,  b)) * 0.08;
	sc += texture(screen_tex, suv + vec2(-b,  b)) * 0.08;
	sc += texture(screen_tex, suv + vec2( b, -b)) * 0.08;
	sc += texture(screen_tex, suv + vec2(-b, -b)) * 0.08;

	// chroma (muy sutil, más en borde)
	vec2 ca = (suv - center) * chroma_amount * ds * (0.20 + 1.25 * per);
	float rch = texture(screen_tex, suv + ca).r;
	float gch = sc.g;
	float bch = texture(screen_tex, suv - ca).b;
	vec3 scr_rgb = mix(sc.rgb, vec3(rch, gch, bch), (0.35 + 0.65 * per) * saturate(ds));

	// =========================
	// 5) Alpha final overlay (controlado, NO exagerado)
	// =========================
	float a = max_alpha * s;
	a *= (0.80 + 0.20 * heartbeat);
	a *= (1.0 - breath_amount * (1.0 - s) * (1.0 - breath));
	a *= mix(0.70, 1.0, saturate(edge));
	a *= gate;

	// 6) Color maldito/demoniaco (NO sangre)
	vec3 cursed_red = vec3(0.38, 0.05, 0.06);
	vec3 sick = vec3(0.18, 0.27, 0.14);

	float sick_mix = sick_tint * s * (0.35 + 0.65 * saturate(edge));
	vec3 col = mix(cursed_red, sick, sick_mix);

	col *= (1.0 - black_crush * s * (0.25 + 0.75 * edge));

	// golpe extra sutil en el dub
	float dub_hit = (max(p1, p2) - p1) * s;
	a *= (1.0 + 0.08 * dub_hit * edge);

	// =========================
	// ✅ Composición final:
	// pantalla distorsionada + overlay miedo encima (con alpha)
	// =========================
	vec3 out_rgb = mix(scr_rgb, col, a);

	COLOR = vec4(out_rgb, 1.0);
}