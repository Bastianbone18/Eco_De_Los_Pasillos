/*
	CRT shader con efecto wiggle por ChatGPT
	Basado en el shader de Yui Kinomoto @arlez80
*/
shader_type canvas_item;

// Pantalla
uniform sampler2D screen_texture : hint_screen_texture;

// CRT Settings
uniform float crt_curve : hint_range(0.0, 1.0) = 0.02;
uniform float crt_scan_line_color : hint_range(0.0, 1.0) = 0.347;
uniform float aperture_grille_rate : hint_range(0.0, 1.0) = 0.4;
uniform float rf_switch_esque_blur : hint_range(0.0, 1.0) = 1.0;
uniform float white_noise_rate : hint_range(0.0, 1.0) = 0.0;

// Wiggle Settings
group_uniforms Wiggle;
uniform float wiggle : hint_range(0.0, 1.5, 0.01) = 0.03;
uniform float wiggle_speed : hint_range(0.0, 100.0, 1.0) = 25.0;

// -------------------- FUNCIONES AUXILIARES ----------------------

float random(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453);
}

float onOff(float a, float b, float c, float t) {
	return step(c, sin((t * 0.001) + a * cos((t * 0.001) * b)));
}

vec2 jumpy(vec2 uv, float t) {
	vec2 look = uv;
	float window = 1.0 / (1.0 + 80.0 * pow(look.y - mod(t / 4.0, 1.0), 2.0));
	look.x += 0.05 * sin(look.y * 10.0 + t) / 20.0 * onOff(4.0, 4.0, 0.3, t) * (0.5 + cos(t * 20.0)) * window;
	float vShift = (0.1 * wiggle) * 0.4 * onOff(2.0, 3.0, 0.9, t) * (sin(t) * sin(t * 20.0) + (0.5 + 0.1 * sin(t * 200.0) * cos(t)));
	look.y = mod(look.y - 0.01 * vShift, 1.0);
	return look;
}

// -------------------- FUNCIÓN PRINCIPAL ----------------------

void fragment() {
	float t = TIME * wiggle_speed;

	// Aplicar distorsión tipo "wiggle" a UVs
	vec2 base_uv = jumpy(UV, t);
	vec2 base_screen_uv = jumpy(SCREEN_UV, t);

	// Curvatura CRT
	vec2 crt_curve_shift = (vec2(1.0) - sin(base_uv.yx * PI)) * crt_curve;
	vec2 crt_curve_scale = vec2(1.0) + crt_curve_shift * 2.0;
	vec2 texture_fixed_uv = base_uv * crt_curve_scale - crt_curve_shift;
	vec2 fixed_uv = base_screen_uv * crt_curve_scale - crt_curve_shift;

	// Validar área visible
	float enable_color = float(0.0 <= texture_fixed_uv.x && texture_fixed_uv.x <= 1.0 &&
	                           0.0 <= texture_fixed_uv.y && texture_fixed_uv.y <= 1.0);

	// Color base + blur horizontal (efecto RF)
	COLOR.rgb = (
		(texture(screen_texture, fixed_uv).rgb * (1.0 - rf_switch_esque_blur * 0.5)) +
		(
			texture(screen_texture, fixed_uv + vec2(-SCREEN_PIXEL_SIZE.x * 3.1, 0.0)).rgb +
			texture(screen_texture, fixed_uv + vec2(SCREEN_PIXEL_SIZE.x * 3.1, 0.0)).rgb
		) * (rf_switch_esque_blur * 0.25)
	) * enable_color;
	COLOR.a = 1.0;

	// Ruido blanco
	vec2 aperture_pixel = vec2(floor((fixed_uv.x / SCREEN_PIXEL_SIZE.x) / 3.0) * 3.0, fixed_uv.y);
	float white_noise = random(aperture_pixel + vec2(sin(TIME * 0.543254), cos(TIME * 0.254323563)));
	COLOR.rgb = mix(COLOR.rgb, vec3(white_noise), white_noise_rate * enable_color);

	// Aperture grille ROTADO (ahora en Y)
	float aperture_point_y = mod(((SCREEN_UV.y * crt_curve_scale.y) - crt_curve_shift.y) / SCREEN_PIXEL_SIZE.y, 3.0);
	float r_rate = clamp(1.0 - aperture_point_y, 0.0, 1.0) + clamp(aperture_point_y - 2.0, 0.0, 1.0);
	float g_rate = clamp(1.0 - abs(1.0 - aperture_point_y), 0.0, 1.0);
	float b_rate = 1.0 - r_rate - g_rate;

	COLOR = clamp(COLOR * vec4(normalize(vec3(
		clamp(r_rate, aperture_grille_rate, 1.0),
		clamp(g_rate, aperture_grille_rate, 1.0),
		clamp(b_rate, aperture_grille_rate, 1.0)
	)), 1.0), vec4(0.0), vec4(1.0));

	// Scanlines horizontales (difuminadas)
	float scanline_x = mod(fixed_uv.x / SCREEN_PIXEL_SIZE.x, 2.0);
	float scanline_fade = smoothstep(0.4, 0.6, abs(scanline_x - 1.0));
	COLOR = mix(COLOR, vec4(0.0, 0.0, 0.0, 1.0), scanline_fade * crt_scan_line_color);
}
