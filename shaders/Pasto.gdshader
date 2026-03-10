shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Colores y texturas base
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap, repeat_enable;

// Parámetros de transparencia
uniform float alpha_scissor_threshold;
uniform float point_size : hint_range(0, 128);

// Propiedades de material
uniform float roughness : hint_range(0, 1);
uniform float metallic;
uniform float specular;

// Texturas adicionales
uniform sampler2D texture_metallic : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest_mipmap, repeat_enable;

// Escala y offset UV
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// Grupo de parámetros de viento
group_uniforms wind;
uniform sampler2D noise_tex;
uniform float wind_speed = 0.1;
uniform float wind_strength = 0.01;

void vertex() {
    // Ajuste de UV
    UV = UV * uv1_scale.xy + uv1_offset.xy;

    // Aplicación de ruido basado en el tiempo
    float offset = TIME * wind_speed;
    float noise = texture(noise_tex, vec2(VERTEX.x - offset, VERTEX.z)).r;

    // Centrado del ruido y escalado
    noise = (noise - 0.5) * wind_strength;

    // Desplazamiento del vértice
    VERTEX.xy += noise * length(VERTEX.y) * length(VERTEX.xz);
}

void fragment() {
    // Base UV
    vec2 base_uv = UV;

    // Textura del albedo
    vec4 albedo_tex = texture(texture_albedo, base_uv);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    // Textura de metálico
    float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
    METALLIC = metallic_tex * metallic;

    // Textura de rugosidad
    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0); // Canal R predeterminado
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;

    // Especularidad
    SPECULAR = specular;

    // Transparencia
    ALPHA *= albedo.a * albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
