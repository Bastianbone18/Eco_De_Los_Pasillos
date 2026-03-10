shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

uniform float vignette_power : hint_range(0.5, 3.0) = 1.35;
uniform float vignette_size  : hint_range(0.0, 1.0) = 0.74;  // bordes más pequeños
uniform float vignette_soft  : hint_range(0.0, 1.0) = 0.20;

uniform float wobble        : hint_range(0.0, 1.0) = 0.55;   // mareo
uniform float double_vision : hint_range(0.0, 2.0) = 0.55;
uniform float noise_amt     : hint_range(0.0, 1.0) = 0.06;

uniform vec4 red_color : source_color = vec4(0.9, 0.1, 0.08, 1.0);

// --- PULSO (shader-only) ---
uniform float pulse_speed  : hint_range(0.1, 10.0) = 2.6;    // 2.0 lento, 3.5 fuerte
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;    // 0.25 sutil, 0.45 notorio
uniform float pulse_jitter : hint_range(0.0, 1.0) = 0.18;    // irregularidad del pulso

float hash(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;

	float t = TIME;

	// --- Pulso orgánico (0..1) + un poquito de irregularidad ---
	float p0 = sin(t * pulse_speed) * 0.5 + 0.5;
	float p1 = sin(t * (pulse_speed * 0.63) + 1.7) * 0.5 + 0.5;
	float pulse = mix(p0, p0 * (0.75 + 0.25 * p1), pulse_jitter);

	// strength “late” sin romper que vuelva a 0 limpio
	float pulsed_strength = mix(strength, strength * pulse, pulse_amount);

	// Intensidad NO lineal (más golpe cuando es alto)
	float k = pow(pulsed_strength, 1.25);

	// Drift lento (desorientación)
	vec2 drift = vec2(sin(t * 0.55), cos(t * 0.43)) * (0.0032 * wobble) * k;

	// Wobble doble (orgánico)
	vec2 wob = vec2(
		sin(centered.y * 7.0 + t * 1.55) + sin(centered.y * 3.3 + t * 0.75),
		cos(centered.x * 6.0 + t * 1.35) + cos(centered.x * 2.9 + t * 0.70)
	) * (0.0046 * wobble) * k;

	// Micro “lens bend” hacia bordes (golpe)
	float r = length(centered);
	vec2 bend = centered * (r * r) * (0.0022 * wobble) * k;

	vec2 distort = drift + wob + bend;

	// Doble visión suave
	vec2 dv = vec2(0.0038, 0.0014) * double_vision * k;

	vec4 c0 = texture(SCREEN_TEXTURE, uv + distort);
	vec4 c1 = texture(SCREEN_TEXTURE, uv + distort + dv);
	vec4 c2 = texture(SCREEN_TEXTURE, uv + distort - dv);

	vec4 col = (c0 * 0.62 + c1 * 0.19 + c2 * 0.19);

	// Vignette rojo (bordes más pequeños)
	float vig = smoothstep(vignette_size - vignette_soft, vignette_size + vignette_soft, r);
	vig = pow(vig, vignette_power);

	vec3 overlay = red_color.rgb * (vig * k);

	// Ruido retro suave (también late un poco)
	float n = hash(uv * vec2(850.0, 520.0) + TIME);
	overlay += (n - 0.5) * noise_amt * (0.65 + 0.35 * pulse) * k;

	// Mezcla final (vuelve a normal cuando k->0)
	col.rgb = mix(col.rgb, col.rgb * 0.93 + overlay, 0.72 * k);

	COLOR = col;
}
