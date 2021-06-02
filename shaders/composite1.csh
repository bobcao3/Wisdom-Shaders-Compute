#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

layout (r11f_g11f_b10f) uniform image2D colorimg5;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"

#include "/configs.glsl"

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
    if (clamp(spos, vec3(0.0), vec3(1.0)) != spos) return 1.0;

    return VSM(spos.z, spos.xy);
}

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

#define INCLUDE_IBL

#include "/libs/lighting.glsl"

#define SSPT

uniform usampler2D shadowcolor0;

#include "/libs/voxel_lighting.glsl"

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * 2;
    ivec2 iuv_orig = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    float depth = texelFetch(colortex4, iuv_orig, 0).r;

#ifdef SSPT
    if (depth < 1.0)
    {
        z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);
        getRand();

        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        int lod = 3;

        const float zThickness = 0.25;
        const float stride = 2.0;
        const float stride_multiplier = 1.3;
        
        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        vec4 lm_specular_encoded = texelFetch(colortex8, iuv, 0).rgba;

        vec2 lmcoord = lm_specular_encoded.rg;

        float roughness = (1.0 - lm_specular_encoded.b);
        // float metalic = lm_specular_encoded.a;

        bool refine = roughness < 0.3;

        vec3 color = vec3(0.0);

        vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;

        #define SSPT_RAYS 2 // [1 2 4 8 16]

        float samples_taken = 0.0;

        for (int i = 0; i < SSPT_RAYS; i++)
        {
            vec2 rand2d = vec2(getRand(), getRand());

            float pdf;
            vec3 sample_dir = ImportanceSampleGGX(rand2d, view_normal, view_dir, roughness, pdf);
            samples_taken++;

            if (dot(sample_dir, view_normal) <= 0.0)
            {
                rand2d = vec2(getRand(), getRand());
                sample_dir = ImportanceSampleGGX(rand2d, view_normal, view_dir, roughness, pdf);
                samples_taken++;
            }

            if (dot(sample_dir, view_normal) <= 0.0)
            {
                // Bruh
                sample_dir = reflect(sample_dir, view_normal);
            }

            ivec2 hit_pos = raytrace(view_pos + view_normal * 0.2, iuv, sample_dir, stride, stride_multiplier, zThickness, lod, refine);

            bool hit = false;

            vec3 hit_proj_pos;
            vec3 hit_view_pos;
            vec3 hit_wpos;

            vec3 real_sampled_dir;

            if (hit_pos != ivec2(-1) && hit_pos != iuv)
            {
                hit_proj_pos = getProjPos(hit_pos);
                hit_view_pos = proj2view(hit_proj_pos);
                hit_wpos = view2world(hit_view_pos);

                real_sampled_dir = normalize(hit_view_pos - view_pos);

                if (abs(dot(real_sampled_dir, sample_dir)) > 0.7)
                    hit = true;
            }

            if (hit)
            {
                //vec3 hit_color = texelFetch(colortex2, hit_pos, 0).rgb;

                vec3 radiance;

                {
                    vec3 albedo = texelFetch(colortex6, hit_pos, 0).rgb;

                    vec4 normal_flag_encoded = texelFetch(colortex7, hit_pos, 0);
                    vec4 lm_specular_encoded = texelFetch(colortex8, hit_pos, 0).rgba;

                    Material mat;
                    mat.albedo = albedo;
                    mat.lmcoord = lm_specular_encoded.rg;
                    mat.roughness = (1.0 - lm_specular_encoded.b);
                    mat.metalic = lm_specular_encoded.a;
                    mat.flag = normal_flag_encoded.a;

                    vec3 ao = vec3(1.0);
                    vec3 view_normal = mat3(gbufferModelView) * normal_flag_encoded.rgb;

                    radiance = getLighting(mat, view_normal, -sample_dir, hit_view_pos, hit_wpos, ao);
                }

                color += radiance * max(0.0, dot(view_normal, real_sampled_dir));
            }
            else
            {
                vec3 world_sample_dir = mat3(gbufferModelViewInverse) * sample_dir;

                vec2 skybox_uv = project_skybox2uv(world_sample_dir);

                float skybox_lod = pow(roughness, 0.25) * 6.0;

                int skybox_lod0 = int(floor(skybox_lod));
                int skybox_lod1 = int(ceil(skybox_lod));
                vec3 skybox_color = mix(
                    sampleLODmanual(colortex3, skybox_uv, skybox_lod0).rgb,
                    sampleLODmanual(colortex3, skybox_uv, skybox_lod1).rgb,
                    fract(skybox_lod));

                color += skybox_color * max(0.0, dot(view_normal, sample_dir)) * smoothstep(0.1, 1.0, lmcoord.y);
            }
        }

        color /= samples_taken;

        imageStore(colorimg5, iuv_orig, vec4(color, 1.0));
    }
#endif
}