shader_type canvas_item;

uniform float resolution_x : hint_range(1.0, 1000.0) = 320.0; // Ancho de la resolución
uniform float resolution_y : hint_range(1.0, 1000.0) = 240.0; // Alto de la resolución
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float scanlines_width : hint_range(0.0, 10.0) = 2.0;
uniform float static_noise_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float noise_opacity : hint_range(0.0, 1.0) = 0.2;
uniform float noise_speed : hint_range(0.0, 5.0) = 1.0;
uniform float roll_speed : hint_range(0.0, 10.0) = 1.0;
uniform float roll_size : hint_range(1.0, 20.0) = 5.0;
uniform float roll_variation : hint_range(0.1, 10.0) = 1.5;
uniform float distort_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float aberration : hint_range(0.0, 2.0) = 0.1;
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.1;
uniform bool pixelate = true;
uniform bool roll = true;
uniform bool discolor = true;
uniform bool clip_warp = true;
uniform bool overlay = false;

vec2 warp(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    uv *= 1.0 + pow(abs(uv.yx), vec2(2.0)) * vec2(0.25, 0.5);
    uv = uv * 0.5 + 0.5;
    return uv;
}

float random(vec2 uv)
{
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv)
{
    vec2 integer = floor(uv);
    vec2 fractional = fract(uv);
    fractional = fractional * fractional * (3.0 - 2.0 * fractional);

    return mix(
        mix(random(integer), random(integer + vec2(1.0, 0.0)), fractional.x),
        mix(random(integer + vec2(0.0, 1.0)), random(integer + vec2(1.0, 1.0)), fractional.x),
        fractional.y
    );
}

float vignette(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    return clamp(pow(1.0 - dot(uv, uv), 0.4), 0.0, 1.0);
}

float border(vec2 uv)
{
    return clamp(smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x) * smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.85, uv.y), 0.0, 1.0);
}

void fragment()
{
    vec2 uv = overlay ? warp(SCREEN_UV) : warp(UV); 
    vec2 text_uv = uv;
    vec2 roll_uv = vec2(0.0);
    float time = roll ? TIME : 0.0;

    // Pixelate the texture based on the given resolution.
    if (pixelate)
    {
        vec2 resolution = vec2(resolution_x, resolution_y);
        text_uv = ceil(uv * resolution) / resolution;
    }

    // Rolling effect
    float roll_line = 0.0;
    if (roll || noise_opacity > 0.0)
    {
        roll_line = smoothstep(0.3, 0.9, sin(uv.y * roll_size - (time * roll_speed)));
        roll_line *= roll_line * smoothstep(0.3, 0.9, sin(uv.y * roll_size * roll_variation - (time * roll_speed * roll_variation)));
        roll_uv = vec2((roll_line * distort_intensity * (1.0 - UV.x)), 0.0);
    }

    vec4 text;
    if (roll)
    {
        text.r = texture(TEXTURE, text_uv + roll_uv * 0.8 + vec2(aberration, 0.0) * 0.1).r;
        text.g = texture(TEXTURE, text_uv + roll_uv * 1.2 - vec2(aberration, 0.0) * 0.1).g;
        text.b = texture(TEXTURE, text_uv + roll_uv).b;
        text.a = 1.0;
    }
    else
    {
        text.r = texture(TEXTURE, text_uv + vec2(aberration, 0.0) * 0.1).r;
        text.g = texture(TEXTURE, text_uv - vec2(aberration, 0.0) * 0.1).g;
        text.b = texture(TEXTURE, text_uv).b;
        text.a = 1.0;
    }

    float r = text.r;
    float g = text.g;
    float b = text.b;

    // Apply the grille effect
    if (grille_opacity > 0.0)
    {
        float g_r = smoothstep(0.85, 0.95, abs(sin(uv.x * (resolution_x * 3.14159265))));
        r = mix(r, r * g_r, grille_opacity);

        float g_g = smoothstep(0.85, 0.95, abs(sin(1.05 + uv.x * (resolution_x * 3.14159265))));
        g = mix(g, g * g_g, grille_opacity);

        float b_b = smoothstep(0.85, 0.95, abs(sin(2.1 + uv.x * (resolution_x * 3.14159265))));
        b = mix(b, b * b_b, grille_opacity);
    }

    // Apply brightness
    text.r = clamp(r * brightness, 0.0, 1.0);
    text.g = clamp(g * brightness, 0.0, 1.0);
    text.b = clamp(b * brightness, 0.0, 1.0);

    // Scanlines effect
    float scanlines = 0.5;
    if (scanlines_opacity > 0.0)
    {
        scanlines = smoothstep(scanlines_width, scanlines_width + 0.5, abs(sin(uv.y * (resolution_y * 3.14159265)))); 
        text.rgb = mix(text.rgb, text.rgb * vec3(scanlines), scanlines_opacity);
    }

    // Apply banded noise
    if (noise_opacity > 0.0)
    {
        float noise = smoothstep(0.4, 0.5, noise(uv * vec2(2.0, 200.0) + vec2(10.0, (TIME * (noise_speed)))));
        roll_line *= noise * scanlines * clamp(random((ceil(uv * vec2(resolution_x, resolution_y)) / vec2(resolution_x, resolution_y)) + vec2(TIME * 0.8, 0.0)) + 0.8, 0.0, 1.0);
        text.rgb = clamp(mix(text.rgb, text.rgb + roll_line, noise_opacity), vec3(0.0), vec3(1.0));
    }

    // Apply static noise
    if (static_noise_intensity > 0.0)
    {
        text.rgb += clamp(random((ceil(uv * vec2(resolution_x, resolution_y)) / vec2(resolution_x, resolution_y)) + fract(TIME)), 0.0, 1.0) * static_noise_intensity;
    }

    // Apply border and vignette
    text.rgb *= border(uv);
    text.rgb *= vignette(uv);
    if (clip_warp)
    {
        text.rgb *= smoothstep(0.0, 0.5, abs(warp(uv).x - warp(uv).y));
    }

    COLOR = text;
}
