uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform usampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex15;

#define OUTPUT_IMAGE colorimg2

layout (r11f_g11f_b10f) uniform image2D OUTPUT_IMAGE;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/color.glslinc"

#include "/programs/post/gtao_spatial.glsl"

#include "/configs.glsl"

#define VL

// uniform sampler2D shadowcolor1;

#include "/libs/shadows.glsl"

#include "/libs/atmosphere.glsl"

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

    vec3 color = vec3(0.0);

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

    if (depth < 1.0)
    {
        uvec2 albedo_specular = texelFetch(colortex6, iuv, 0).xy;

        vec3 albedo = fromGamma(unpackUnorm4x8(albedo_specular.x).rgb);
        vec4 lm_specular_encoded = unpackUnorm4x8(albedo_specular.y);

        vec4 normal_flag_encoded = texelFetch(colortex7, iuv, 0);

        Material mat;
        mat.albedo = albedo;
        mat.lmcoord = lm_specular_encoded.rg;
        mat.roughness = pow2(1.0 - lm_specular_encoded.b);
        mat.metalic = lm_specular_encoded.a;
        mat.flag = normal_flag_encoded.a;
        mat.view_normal = mat3(gbufferModelView) * normal_flag_encoded.rgb;

#ifndef SSPT
        const vec3 ao = getAO(iuv, depth, albedo);
#else
        const vec3 ao = vec3(1.0);
#endif
        
        color = getLighting(mat, normalize(view_pos), view_pos, world_pos, ao);
    }
    else
    {
        color = starField(world_dir);
        color += smoothstep(0.9999, 0.99991, dot(world_sun_dir, world_dir)) * texelFetch(colortex3, ivec2(viewWidth - 1, 0), 0).rgb * 20.0;
    }

    if (depth < 1.0)
    {
        vec3 spos_start = world2shadowLinear(view2world(vec3(0.0)));
        vec3 spos_end = world2shadowLinear(vec3(world_pos));
        vec3 spos_stride = (spos_end - spos_start) * 0.25;

        float jitter = fract(texelFetch(noisetex, iuv & 0xFF, 0).r + getRand());

        float fog_z = 0.0;
        float stride_z = length(view_pos.xyz) * 0.25;

        for (int i = 0; i < 4; i++)
        {
            float shadow_depth;
            vec3 shadow_pos = shadowLinear2Proj(spos_start + spos_stride * (float(i) + jitter)) * 0.5 + 0.5;

            float shadow = shadowTexSmooth(shadow_pos, shadow_depth, 1e-4);

            fog_z += shadow * stride_z;
        }

        vec4 atmos_far = texture(colortex5, uv * 0.25 + vec2(0.25));
        vec4 atmos_1024 = texture(colortex5, uv * 0.25 + vec2(0.25, 0.0));
        vec4 atmos_512 = texture(colortex5, uv * 0.25 + vec2(0.0, 0.25));
        vec4 atmos_256 = texture(colortex5, uv * 0.25 + vec2(0.0, 0.0));

        vec4 atmos;

        if (fog_z > 1024.0)
        {
            atmos = mix(atmos_1024, atmos_far, clamp((fog_z - 1024.0) / 1024.0, 0.0, 1.0));
        }
        else if (fog_z > 512.0)
        {
            atmos = mix(atmos_512, atmos_1024, clamp((fog_z - 512.0) / 512.0, 0.0, 1.0));
        }
        else if (fog_z > 256.0)
        {
            atmos = mix(atmos_256, atmos_512, clamp((fog_z - 256.0) / 256.0, 0.0, 1.0));
        }
        else
        {
            atmos = mix(vec4(0.0, 0.0, 0.0, 1.0), atmos_256, clamp(fog_z / 256.0, 0.0, 1.0));
        }

        color = color * atmos.a + atmos.rgb;
    }
    else
    {
        color += texture(colortex5, uv * 0.25 + vec2(0.25)).rgb;
    }

    return color;
}

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    float depth = texelFetch(depthtex0, iuv, 0).r;

    imageStore(OUTPUT_IMAGE, iuv, vec4(compute_lighting(iuv, depth), 0.0));
}