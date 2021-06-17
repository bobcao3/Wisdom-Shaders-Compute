uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex15;

layout (r11f_g11f_b10f) uniform image2D colorimg5;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"

#include "/programs/post/gtao_spatial.glsl"

#include "/configs.glsl"

#define VL

uniform sampler2D shadowtex1;

uniform sampler2D shadowcolor1;

float VSM(float t, vec2 uv)
{
    vec2 means = texture(shadowcolor1, uv).rg;
    float e_x = means.x;
    float var = means.y - e_x * e_x;

    float p_max = (var + 1e-7) / (var + pow2(max(0.0, t - e_x)) + 1e-7);

    const float c = 500;

    float depth_test_exp = clamp(exp(-c * (t - e_x)), 0.0, 1.0);

    return min(p_max, depth_test_exp);
}

float shadowTexSmooth(in vec3 spos, out float depth, float bias) {
    if (clamp(spos, vec3(0.01), vec3(0.99)) != spos) return 1.0;

    return VSM(spos.z, spos.xy);
}

#include "/libs/atmosphere.glsl"

/* RENDERTARGETS: 2 */

#define SCREEN_SPACE_SHADOWS

#define SSPT

#ifndef SSPT
#define INCLUDE_IBL
#endif

#define SUBSURFACE

#include "/libs/lighting.glsl"

#define SSPT


vec3 compute_lighting(ivec2 iuv, float depth)
{
    z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);
    getRand();

    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    vec3 proj_pos = getProjPos(uv, depth);
    vec3 view_pos = proj2view(proj_pos);
    vec3 world_pos = view2world(view_pos);
    vec3 world_dir = normalize(world_pos);

    float hash0 = getRand();
    float hash1 = getRand();
    
    vec3 color = vec3(0.0);

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

#if GROUP == 1
    vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;

    vec4 normal_flag_encoded = texelFetch(colortex7, iuv, 0);
    vec4 lm_specular_encoded = texelFetch(colortex8, iuv, 0).rgba;

    Material mat;
    mat.albedo = albedo;
    mat.lmcoord = lm_specular_encoded.rg;
    mat.roughness = (1.0 - lm_specular_encoded.b);
    mat.metalic = lm_specular_encoded.a;
    mat.flag = normal_flag_encoded.a;

#ifndef SSPT
    vec3 ao = getAO(iuv, depth, albedo);
#else
    vec3 ao = vec3(1.0);
#endif

    vec3 view_normal = mat3(gbufferModelView) * normal_flag_encoded.rgb;
    
    color = getLighting(mat, view_normal, -normalize(view_pos), view_pos, world_pos, ao);
#else
    color += starField(world_dir);
    color += smoothstep(0.9999, 0.99991, dot(world_sun_dir, world_dir)) * texelFetch(colortex3, ivec2(viewWidth - 1, 0), 0).rgb * 20.0;
#endif

    float l_limit = Ra;

    float atmos_hash = getRand();
 
    if (depth < 1.0)
    {
        l_limit = length(world_pos);
    }
    else
    {
        atmos_hash = 0.5;
    }

    vec4 skybox_color = scatter(vec3(0.0, cameraPosition.y, 0.0), world_dir, world_sun_dir, l_limit, atmos_hash, depth >= 1.0);
    color = color * skybox_color.a + skybox_color.rgb;

    return color;
}

void main()
{
#if GROUP == 0

    ivec2 iuv00 = ivec2(gl_GlobalInvocationID.xy) * 2;
    float depth00 = texelFetch(depthtex0, iuv00, 0).r;

    ivec2 iuv01 = ivec2(gl_GlobalInvocationID.xy * 2 + ivec2(0, 1));
    float depth01 = texelFetch(depthtex0, iuv01, 0).r;

    ivec2 iuv10 = ivec2(gl_GlobalInvocationID.xy * 2 + ivec2(1, 0));
    float depth10 = texelFetch(depthtex0, iuv10, 0).r;

    ivec2 iuv11 = ivec2(gl_GlobalInvocationID.xy * 2 + ivec2(1, 1));
    float depth11 = texelFetch(depthtex0, iuv11, 0).r;

    bool has_sky = (depth00 >= 1.0 || depth01 >= 1.0 || depth10 >= 1.0 || depth11 >= 1.0);

    if (has_sky)
    {
        vec3 color = compute_lighting(iuv00, 1.0);

        if (depth00 >= 1.0) imageStore(colorimg5, iuv00, vec4(color, 0.0));
        if (depth01 >= 1.0) imageStore(colorimg5, iuv01, vec4(color, 0.0));
        if (depth10 >= 1.0) imageStore(colorimg5, iuv10, vec4(color, 0.0));
        if (depth11 >= 1.0) imageStore(colorimg5, iuv11, vec4(color, 0.0));
    }

#else

    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    float depth = texelFetch(depthtex0, iuv, 0).r;

    if (depth < 1.0) imageStore(colorimg5, iuv, vec4(compute_lighting(iuv, depth), 0.0));

#endif

}