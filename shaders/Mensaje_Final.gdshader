shader_type canvas_item;

uniform float intensity : hint_range(0.0,1.0) = 0.0;

uniform float glitch_strength : hint_range(0.0,5.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0,5.0) = 0.0;
uniform float noise_strength : hint_range(0.0,5.0) = 0.0;

uniform float hell_red : hint_range(0.0,1.0) = 0.0;
uniform float darkness : hint_range(0.0,1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {

    vec2 uv = SCREEN_UV;

    // ---------------------------
    // Distorsión radial (pantalla se deforma)
    // ---------------------------
    vec2 center = vec2(0.5);
    vec2 offset = uv - center;
    float dist = length(offset);

    uv += offset * dist * 0.25 * intensity;

    // ---------------------------
    // Glitch horizontal
    // ---------------------------
    float glitch = step(0.95, rand(vec2(TIME * 0.5, uv.y * 50.0)));
    uv.x += glitch * (rand(vec2(uv.y, TIME)) - 0.5) * 0.05 * glitch_strength * intensity;

    // ---------------------------
    // Aberración cromática
    // ---------------------------
    float shift = 0.003 * chromatic_aberration * intensity;

    float r = texture(screen_texture, uv + vec2(shift,0)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - vec2(shift,0)).b;

    vec3 col = vec3(r,g,b);

    // ---------------------------
    // Ruido VHS
    // ---------------------------
    float n = rand(uv * TIME * 50.0);
    col += (n - 0.5) * 0.15 * noise_strength * intensity;

    // ---------------------------
    // Scanlines VHS
    // ---------------------------
    float scan = sin(uv.y * 800.0) * 0.04 * intensity;
    col -= scan;

    // ---------------------------
    // Vignette oscuro
    // ---------------------------
    float vignette = smoothstep(0.9,0.2,dist);
    col *= mix(1.0, vignette, intensity);

    // ---------------------------
    // Oscuridad extrema
    // ---------------------------
    col *= (1.0 - darkness);

    // ---------------------------
    // Rojo infernal pulsante
    // ---------------------------
    float pulse = sin(TIME * 3.0) * 0.1 + 0.1;
    vec3 red_tint = vec3(0.4, 0.02, 0.02) + pulse;

    col = mix(col, red_tint, hell_red);

    COLOR = vec4(col,1.0);
}