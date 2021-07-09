uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform usampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex12;

layout (r11f_g11f_b10f) uniform image2D colorimg5;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"
#include "/libs/color.glslinc"

#include "/configs.glsl"

// uniform sampler2D shadowcolor1;

#include "/libs/shadows.glsl"

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

#define SSPT

#include "/libs/lighting.glsl"

//uniform usampler2D shadowcolor0;

layout (r32ui) uniform uimage2D shadowcolorimg0;

#include "/libs/voxel_raytracing.glsl"

#define SSPT_RAYS 1 // [1 2 4 8 16]

#ifdef RAY_GUIDING
shared vec2 sampleLoc[8][8][SSPT_RAYS];
shared float contributions[8][8][SSPT_RAYS];
shared float weights[8][8];

shared float cdf[8];

int binarySearchColumns(float r)
{
    int i = 4;

    // i = 0;

    // for (; i < 8; i++)
    // {
    //     float curr = cdf[i];
    //     if (curr > r) return i;
    // }

    int low = 0;
    int high = 7;

    for (int _t = 0; _t < 4; _t++)
    {
        float curr = cdf[i];
        float curr_prev = i > 0 ? cdf[i - 1] : 0.0;
        if (curr_prev < r && r <= curr) break;

        if (curr > r)
        {
            high = i - 1;
        }
        else
        {
            low = i + 1;
        }

        i = low + ((high - low) >> 1);
    }

    return i;
}

int binarySearchRows(int column, float r)
{
    int i = 4;

    // i = 0;

    // for (; i < 8; i++)
    // {
    //     float curr = weights[column][i];
    //     if (curr > r) return i;
    // }

    int low = 0;
    int high = 7;

    for (int _t = 0; _t < 4; _t++)
    {
        float curr = weights[column][i];
        float curr_prev = i > 0 ? weights[column][i - 1] : 0.0;
        if (curr_prev < r && r <= curr) break;

        if (curr > r)
        {
            high = i - 1;
        }
        else
        {
            low = i + 1;
        }

        i = low + ((high - low) >> 1);
    }
    return i;
}

float getSelectionPDF(int i, int j)
{
    float pdf = (cdf[i] - (i > 0 ? cdf[i - 1] : 0.0)) * 8.0;
    pdf *= (weights[i][j] - (j > 0 ? weights[i][j - 1] : 0.0)) * 8.0;

    return max(1.0, pdf);
}
#endif

bool traceRayHybrid(ivec2 iuv, vec3 view_pos, vec3 view_normal, vec3 sample_dir, vec3 world_pos, vec3 world_normal, bool refine, float vox_lmcoord_approx, out Material mat, out vec3 hit_view_pos, out vec3 hit_wpos, out ivec2 hit_iuv, out vec3 real_sampled_dir, out vec3 transmission)
{
// #if !defined(SPECULAR_PT) && defined(SPECULAR_ONLY)
//     return false;
// #endif

    // SSR stuff
    int lod = 3;
    const float zThickness = abs(view_pos.z) * 0.1;
    const float stride = 2.0;
    const float stride_multiplier = 1.35;

    // Hit info
    bool hit = false;
    ivec2 hit_pos;
    vec3 hit_proj_pos;

    // Voxel ray tracing info
    vec3 world_sample_dir = mat3(gbufferModelViewInverse) * sample_dir;
    bool vox_hit = false;
    vec3 vox_hit_normal;
    uint vox_data;
    vec3 tint = vec3(1.0);

#ifdef SSR_FIRST
    if (!hit)
    {
        hit_pos = raytrace(view_pos + view_normal * 0.05, iuv, sample_dir, stride, stride_multiplier, zThickness, lod, refine);

        if (hit_pos != ivec2(-1) && hit_pos != iuv)
        {
            vec3 t_hit_proj_pos = getProjPos(hit_pos);
            vec3 t_hit_view_pos = proj2view(t_hit_proj_pos);
            vec3 t_hit_wpos = view2world(t_hit_view_pos);

            vec3 t_real_sampled_dir = normalize(t_hit_view_pos - view_pos);

            // Confirm SSR
            if (max(dot(t_real_sampled_dir, sample_dir), 0.0) > 0.9 && t_hit_proj_pos.z < 1.0)
            {
                hit = true;
                hit_proj_pos = t_hit_proj_pos;
                hit_view_pos = t_hit_view_pos;
                hit_wpos = t_hit_wpos;
                real_sampled_dir = t_real_sampled_dir;
            }
        }
    }
#endif

    // Voxel ray tracing
    if (!hit) {
        vox_hit = voxel_march(world_pos + world_normal * 0.05, world_sample_dir, 200.0, vox_hit_normal, hit_wpos, vox_data, tint);
        hit_view_pos = (gbufferModelView * vec4(hit_wpos, 1.0)).rgb;
        real_sampled_dir = sample_dir;
        hit = vox_hit;

        if (vox_hit)
        {
            vec4 proj_pos = (gbufferProjection * vec4(hit_view_pos, 1.0));
            proj_pos.xyz /= proj_pos.w;
            hit_proj_pos = proj_pos.xyz;

            hit_pos = ivec2((proj_pos.xy * 0.5 + 0.5) * vec2(viewWidth, viewHeight));
            if (hit_pos.x >= 0 && hit_pos.y >= 0 && hit_pos.x < viewWidth && hit_pos.y < viewHeight)
            {
                vec3 t_hit_proj_pos = getProjPos(hit_pos);
                vec3 t_hit_view_pos = proj2view(t_hit_proj_pos);
                vec3 t_hit_wpos = view2world(t_hit_view_pos);

                vec3 t_real_sampled_dir = normalize(t_hit_view_pos - view_pos);

                // Use screen space gbuffer
                if (
                    abs(dot(t_real_sampled_dir, sample_dir)) > 0.8 &&
                    t_hit_proj_pos.z < 1.0 &&
                    abs((t_hit_view_pos.z - hit_view_pos.z) / hit_view_pos.z) < 0.05
                ) {
                    vox_hit = false;
                    hit_proj_pos = t_hit_proj_pos;
                    hit_view_pos = t_hit_view_pos;
                    hit_wpos = t_hit_wpos;
                    real_sampled_dir = t_real_sampled_dir;
                }
            }
        }
    }

    // SSR
#ifndef SSR_FIRST
    if (!hit)
    {
        hit_pos = raytrace(view_pos + view_normal * 0.05, iuv, sample_dir, stride, stride_multiplier, zThickness, lod, refine);

        if (hit_pos != ivec2(-1) && hit_pos != iuv)
        {
            vec3 t_hit_proj_pos = getProjPos(hit_pos);
            vec3 t_hit_view_pos = proj2view(t_hit_proj_pos);
            vec3 t_hit_wpos = view2world(t_hit_view_pos);

            vec3 t_real_sampled_dir = normalize(t_hit_view_pos - view_pos);

            // Confirm SSR
            if (max(dot(t_real_sampled_dir, sample_dir), 0.0) > 0.9 && t_hit_proj_pos.z < 1.0)
            {
                hit = true;
                hit_proj_pos = t_hit_proj_pos;
                hit_view_pos = t_hit_view_pos;
                hit_wpos = t_hit_wpos;
                real_sampled_dir = t_real_sampled_dir;
            }
        }
    }
#endif

    transmission = tint;

    if (!hit) return false;

    // Construct hit material
    {
        vec3 ao = vec3(1.0);

        if (vox_hit)
        {
            bool vox_emmisive = voxIsEmissive(vox_data);

            uint enc_distance;
            vec3 c = unpackUint6Unorm3x6(vox_data, enc_distance);

            mat.albedo = c;
            mat.lmcoord = vec2(0.0);
            mat.roughness = 0.9;
            mat.metalic = 0.0;
            mat.flag = vox_emmisive ? -1.0 : 0.0;
            mat.view_normal = mat3(gbufferModelView) * vox_hit_normal;

            if (vox_emmisive) mat.albedo *= 2.0;

            hit_iuv = ivec2(-1);
        }
        else
        {
            uvec2 albedo_specular = texelFetch(colortex6, iuv, 0).xy;

            vec3 albedo = fromGamma(unpackUnorm4x8(albedo_specular.x).rgb);
            vec4 lm_specular_encoded = unpackUnorm4x8(albedo_specular.y);

            vec4 normal_flag_encoded = texelFetch(colortex7, hit_pos, 0);

            mat.albedo = albedo;
            mat.lmcoord = pow(lm_specular_encoded.rg, vec2(5.0));
            mat.roughness = (1.0 - lm_specular_encoded.b);
            mat.metalic = lm_specular_encoded.a;
            mat.flag = normal_flag_encoded.a;
            mat.view_normal = mat3(gbufferModelView) * normal_flag_encoded.rgb;

            hit_iuv = hit_pos;
        }
    }

    return true;
}

void main()
{
    ivec2 iuv_orig = ivec2(gl_GlobalInvocationID.xy);

#ifdef FULL_RES
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * ivec2(1, 2);
    if ((iuv.x & 0x1) == 0) iuv.y += 1;
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    float depth = texelFetch(depthtex0, iuv, 0).r;
#else
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * 2;
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    float depth = texelFetch(colortex4, iuv_orig, 0).r;

    float d00 = texelFetch(depthtex0, iuv              , 0).r;
    float d01 = texelFetch(depthtex0, iuv + ivec2(0, 1), 0).r;
    float d10 = texelFetch(depthtex0, iuv + ivec2(1, 0), 0).r;
    float d11 = texelFetch(depthtex0, iuv + ivec2(1, 1), 0).r;

    if (abs(depth - d00) < 1e-6)
        iuv = iuv + ivec2(0);
    else if (abs(depth - d01) < 1e-6)
        iuv = iuv + ivec2(0, 1);
    else if (abs(depth - d10) < 1e-6)
        iuv = iuv + ivec2(1, 0);
    else
        iuv = iuv + ivec2(1, 1);
#endif

    ivec2 halfscreen_offset = ivec2(viewWidth, viewHeight) >> 1;

#ifdef RAY_GUIDING
    weights[gl_LocalInvocationID.x][gl_LocalInvocationID.y] = texelFetch(colortex12, iuv_orig + halfscreen_offset, 0).r + 0.05;

    for (int i = 0; i < SSPT_RAYS; i++)
    {
        contributions[gl_LocalInvocationID.x][gl_LocalInvocationID.y][i] = 0.0;
    }

    barrier();
    memoryBarrierShared();
    // Convert each row to a CDF
    if (gl_LocalInvocationID.y == 0)
    {
        float sum = 0.0;
        for (int i = 0; i < 8; i++)
        {
            sum += weights[gl_LocalInvocationID.x][i];
            weights[gl_LocalInvocationID.x][i] = sum;
        }

        float invsum = 1.0 / sum;
        for (int i = 0; i < 8; i++)
        {
            weights[gl_LocalInvocationID.x][i] *= invsum;
        }

        weights[gl_LocalInvocationID.x][7] = 1.0;
    }

    barrier();
    memoryBarrierShared();

    // Construct column CDF
    if (gl_LocalInvocationID.x == 0 && gl_LocalInvocationID.y == 0)
    {
        float sum = 0.0;
        for (int i = 0; i < 8; i++)
        {
            sum += weights[i][7];
            cdf[i] = sum;
        }

        float invsum = 1.0 / sum;
        for (int i = 0; i < 8; i++)
        {
            cdf[i] *= invsum;
        }

        cdf[7] = 1.0;
    }

    barrier();
    memoryBarrierShared();
#endif

#ifdef SSPT
    if (depth < 1.0)
    {
        if (texelFetch(colortex7, iuv, 0).a < 0.0)
        {
            imageStore(colorimg5, iuv_orig, vec4(0.0));
            return;
        }

// #ifdef SPECULAR_ONLY
//         z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv_orig & 0xFF, 0).r * 65535.0));
// #else
        z1 = z2 = z3 = z4 = uint(texelFetch(noisetex, iuv_orig & 0xFF, 0).r * 65535.0) ^ uint(frameCounter % 0xFFFF);
// #endif
        getRand();

        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);
        
        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        uvec2 albedo_specular = texelFetch(colortex6, iuv, 0).xy;

        vec3 albedo = fromGamma(unpackUnorm4x8(albedo_specular.x).rgb);
        vec4 lm_specular_encoded = unpackUnorm4x8(albedo_specular.y);

        vec2 lmcoord = lm_specular_encoded.rg;

        float roughness = pow2(1.0 - lm_specular_encoded.b);
        float metalic = lm_specular_encoded.a;

#ifdef SPECULAR_ONLY
        // if (roughness > 0.7)
        // {
        //     return;
        // }
#endif

        bool refine = roughness < 0.3;

        vec3 color = vec3(0.0);

        float samples_taken = 0.0;

        for (int i = 0; i < SSPT_RAYS; i++)
        {
#ifdef RAY_GUIDING
            int column = binarySearchColumns(getRand());
            int row = binarySearchRows(column, getRand());

            vec2 rand2d = (vec2(getRand(), getRand()) + vec2(column, row)) * (1.0 / 8.0);

            sampleLoc[gl_LocalInvocationID.x][gl_LocalInvocationID.y][i] = rand2d;

            float selectPdf = getSelectionPDF(column, row);
#else
            vec2 rand2d = vec2(getRand(), getRand());
            float selectPdf = 1.0;
#endif

            vec3 sample_dir;
            float pdf;

#ifdef DIFFUSE_ONLY
            if (metalic > (229.5 / 255.0)) continue;
            sample_dir = mat3(gbufferModelView) * ImportanceSampleLambertian(rand2d, world_normal, pdf);
            selectPdf *= pdf;
#endif

#ifdef SPECULAR_ONLY
            roughness = clamp(roughness - 0.1, 0.0, 1.0);
            sample_dir = ImportanceSampleBeckmann(rand2d, view_normal, -view_dir, roughness, pdf);
            // selectPdf *= pdf;
#endif

            if (dot(sample_dir, view_normal) <= 0.0)
            {
                // Bruh
                continue;
            }
            
            selectPdf = max(1e-5, selectPdf);
            samples_taken++;

            // Trace Ray
            vec3 hit_view_pos;
            vec3 hit_wpos;
            Material mat;
            vec3 sample_rad;
            ivec2 hit_iuv;
            vec3 real_sampled_dir;
            vec3 transmission;

            if (traceRayHybrid(iuv, view_pos, view_normal, sample_dir, world_pos, world_normal, true, lmcoord.y, mat, hit_view_pos, hit_wpos, hit_iuv, real_sampled_dir, transmission))
            {
                // Hit
                sample_rad = getLighting(mat, real_sampled_dir, hit_view_pos, hit_wpos, vec3(1.0)) * transmission;

#ifdef SPECULAR_ONLY
                if (hit_iuv != ivec2(-1))
                {
                    sample_rad = max(sample_rad, vec3(texelFetch(colortex2, hit_iuv, 0).rgb));
                }
#endif
            } else {
                // Skybox
                vec2 skybox_uv = project_skybox2uv(normalize(mat3(gbufferModelViewInverse) * sample_dir));

                // float skybox_lod = pow(roughness, 0.25) * 5.0;

                // int skybox_lod0 = int(floor(skybox_lod));
                // int skybox_lod1 = int(ceil(skybox_lod));
                // vec3 skybox_color = mix(
                //     sampleLODmanual(colortex3, skybox_uv, skybox_lod0).rgb,
                //     sampleLODmanual(colortex3, skybox_uv, skybox_lod1).rgb,
                //     fract(skybox_lod));

                vec3 skybox_color = texture(colortex3, skybox_uv).rgb;

                sample_rad = skybox_color * transmission;
            }


#ifdef SPECULAR_ONLY
            const bool do_specular = true;
#else
            const bool do_specular = false;
#endif
            vec3 _kd;

#ifdef SPLIT_SUM
            sample_rad = sample_rad / selectPdf;
#else
            sample_rad = BSDF(-view_dir, real_sampled_dir, view_normal, metalic, roughness, albedo, do_specular, _kd) * sample_rad / selectPdf;
#endif

#ifdef DIFFUSE_ONLY
            sample_rad /= _kd + 1e-5;
#endif

            if (isNanInf(sample_rad)) sample_rad = vec3(0.0);
            if (sample_rad.r > 1e2) sample_rad = vec3(0.0);

            color += sample_rad;

#ifdef RAY_GUIDING
            contributions[gl_LocalInvocationID.x][gl_LocalInvocationID.y][i] = dot(sample_rad * selectPdf, vec3(0.3, 0.5, 0.2));
#endif
        }

        color /= max(1.0, samples_taken);

        imageStore(colorimg5, iuv_orig, vec4(color, 1.0));
    }

#ifdef RAY_GUIDING
    barrier();

    weights[gl_LocalInvocationID.x][gl_LocalInvocationID.y] = 0.0;

    barrier();
    memoryBarrierShared();

    if (gl_LocalInvocationID.x == 0 && gl_LocalInvocationID.y == 0)
    {
        float normalize_max = 0.001;
        for (int i = 0; i < 8; i++)
        {
            for (int j = 0; j < 8; j++)
            {
                for (int k = 0; k < SSPT_RAYS; k++)
                {
                    vec2 dir = sampleLoc[i][j][k];
                    dir *= 8.0;
                    ivec2 iloc = clamp(ivec2(floor(dir)), ivec2(0), ivec2(7));
                    weights[iloc.x][iloc.y] += contributions[i][j][k];
                    // normalize_max = max(normalize_max, contributions[i][j][k]);
                    normalize_max += contributions[i][j][k];
                }
            }
        }

        for (int i = 0; i < 8; i++)
        {
            for (int j = 0; j < 8; j++)
            {
                float last_contrib = texelFetch(colortex12, iuv_orig + halfscreen_offset + ivec2(i, j), 0).r;
                float new_contrib = weights[i][j] / normalize_max;
                new_contrib = max(last_contrib * 0.9, new_contrib);

                imageStore(colorimg5, iuv_orig + halfscreen_offset + ivec2(i, j), vec4(new_contrib, 0.0, 0.0, 1.0));
            }
        }

    }
#endif

#endif
}