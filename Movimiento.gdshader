shader_type spatial;
render_mode blend_mix,
    cull_disabled,
    depth_prepass_alpha,
    shadows_disabled,
    specular_disabled,
    vertex_lighting;

// Parámetros base
uniform bool affine_mapping = false;
uniform float alpha_scissor : hint_range(0, 1) = 0.5;
uniform float jitter : hint_range(0, 1) = 0.25;
uniform ivec2 resolution = ivec2(320, 180);

// Texturas PBR con filtrado nearest mipmap
uniform sampler2D albedo : source_color, filter_nearest_mipmap;
uniform sampler2D metallic_map : filter_nearest_mipmap;
uniform sampler2D roughness_map : filter_nearest_mipmap;
uniform sampler2D normal_map : filter_nearest_mipmap;
uniform sampler2D ao_map : filter_nearest_mipmap;
uniform sampler2D emission_map : filter_nearest_mipmap;

// Parámetros escalares
uniform float normal_scale : hint_range(0, 1) = 1.0;
uniform float emission_energy : hint_range(0, 8) = 1.0;

// Parámetros de color
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(1.0);

vec4 snap_to_position(vec4 base_position)
{
    vec4 snapped_position = base_position;
    snapped_position.xyz = base_position.xyz / base_position.w;

    vec2 snap_resolution = floor(vec2(resolution) * (1.0 - jitter));
    snapped_position.x = floor(snap_resolution.x * snapped_position.x) / snap_resolution.x;
    snapped_position.y = floor(snap_resolution.y * snapped_position.y) / snap_resolution.y;

    snapped_position.xyz *= base_position.w;
    return snapped_position;
}

void vertex()
{
    vec4 snapped_position = snap_to_position(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    if (affine_mapping)
    {
        POSITION = snapped_position;
        POSITION /= abs(POSITION.w);
    }
    else
    {
        POSITION = snapped_position;
    }
}

void fragment()
{
    // Muestreo con filtrado nearest mipmap
    vec4 albedo_tex = texture(albedo, UV);
    float metallic_tex = texture(metallic_map, UV).r;
    float roughness_tex = texture(roughness_map, UV).r;
    vec3 normal_tex = texture(normal_map, UV).rgb;
    float ao_tex = texture(ao_map, UV).r;
    vec3 emission_tex = texture(emission_map, UV).rgb;

    // Cálculo de propiedades finales
    vec4 base_color = albedo_tex * albedo_color * COLOR;
    float final_metallic = metallic_tex; // Usar solo la textura
    float final_roughness = roughness_tex; // Usar solo la textura
    vec3 final_emission = emission_tex * emission_color.rgb * emission_energy;

    // Asignación de propiedades PBR
    ALBEDO = base_color.rgb;
    METALLIC = final_metallic;
    ROUGHNESS = final_roughness;
    EMISSION = final_emission;
    AO = ao_tex;
    AO_LIGHT_AFFECT = 0.5;

    // Mapa normal (opcional)
    if (normal_scale > 0.0) {
        NORMAL_MAP = normal_tex;
        NORMAL_MAP_DEPTH = normal_scale;
    }

    // Transparencia
    ALPHA = base_color.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}