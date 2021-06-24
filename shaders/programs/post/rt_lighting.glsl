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
#include "/libs/color.glslinc"

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

#define SSPT

#include "/libs/lighting.glsl"

uniform usampler2D shadowcolor0;

#include "/libs/voxel_lighting.glsl"

#define SSPT_RAYS 1 // [1 2 4 8 16]

#ifdef RAY_GUIDING
shared vec2 sampleLoc[8][8][SSPT_RAYS];
shared float contributions[8][8][SSPT_RAYS];
shared float weights[8][8];

shared float cdf[8];

int binarySearchColumns(float r)
{
    int i = 4;

    i = 0;
    for (; i < 8; i++)
    {
        if (r <= cdf[i]) break;
    }

    return i;

    for (int _t = 0; _t < 4; _t++)
    {
        float curr = cdf[i];
        float curr_prev = i > 0 ? cdf[i - 1] : 0.0;
        if (curr_prev < r && r < curr) break;

        if (curr < r) i = i + max(1, (7 - i) >> 1);
        if (curr >= r) i = min(i >> 1, i - 1);

        i = clamp(i, 0, 7);
    }
    return i;
}

int binarySearchRows(int column, float r)
{
    int i = 4;

    i = 0;
    for (; i < 8; i++)
    {
        if (r <= weights[column][i]) break;
    }

    return i;

    for (int _t = 0; _t < 4; _t++)
    {
        float curr = weights[column][i];
        float curr_prev = i > 0 ? weights[column][i - 1] : 0.0;
        if (curr_prev <= r && r <= curr) break;

        if (curr < r) i = i + max(1, (7 - i) >> 1);
        if (curr >= r) i = min(i >> 1, i - 1);

        i = clamp(i, 0, 7);
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

bool traceRayHybrid(ivec2 iuv, vec3 view_pos, vec3 view_normal, vec3 sample_dir, vec3 world_pos, vec3 world_normal, bool refine, float vox_lmcoord_approx, out Material mat, out vec3 hit_view_pos, out vec3 hit_wpos, out ivec2 hit_iuv)
{
    // SSR stuff
    int lod = 3;
    const float zThickness = abs(view_pos.z) * 0.1; //0.25;
    const float stride = 2.0;
    const float stride_multiplier = 1.35;

    // Hit info
    bool hit = false;

    vec3 hit_proj_pos;

    vec3 real_sampled_dir;

    // SSR
    ivec2 hit_pos = raytrace(view_pos + view_normal * 0.05, iuv, sample_dir, stride, stride_multiplier, zThickness, lod, refine);

    if (hit_pos != ivec2(-1) && hit_pos != iuv)
    {
        hit_proj_pos = getProjPos(hit_pos);
        float old_z = hit_view_pos.z;
        hit_view_pos = proj2view(hit_proj_pos);
        hit_wpos = view2world(hit_view_pos);

        real_sampled_dir = normalize(hit_view_pos - view_pos);

        // Confirm SSR
        if (abs(dot(real_sampled_dir, sample_dir)) > 0.8 && hit_proj_pos.z < 1.0)
            hit = true;
    }

    // Voxel ray tracing info
    vec3 world_sample_dir = mat3(gbufferModelViewInverse) * sample_dir;
    bool vox_hit = false;
    vec3 vox_hit_normal;
    uint vox_data;

    // Voxel ray tracing
    if (!hit)
    {
        vox_hit = voxel_march(world_pos + world_normal * 0.05, world_sample_dir, 200.0, vox_hit_normal, hit_wpos, vox_data);
        hit_view_pos = (gbufferModelView * vec4(hit_wpos, 1.0)).rgb;
        real_sampled_dir = sample_dir;
        hit = vox_hit;

        if (vox_hit)
        {
            vec4 proj_pos = (gbufferProjection * vec4(hit_view_pos, 1.0));
            proj_pos.xyz /= proj_pos.w;
            hit_pos = ivec2((proj_pos.xy * 0.5 + 0.5) * vec2(viewWidth, viewHeight));
            if (hit_pos.x >= 0 && hit_pos.y >= 0 && hit_pos.x < viewWidth && hit_pos.y < viewHeight)
            {
                hit_proj_pos = getProjPos(hit_pos);
                float old_z = hit_view_pos.z;
                hit_view_pos = proj2view(hit_proj_pos);
                hit_wpos = view2world(hit_view_pos);

                vec3 _real_sampled_dir = normalize(hit_view_pos - view_pos);

                // Use screen space gbuffer
                if (
                    abs(dot(_real_sampled_dir, sample_dir)) > 0.8 &&
                    hit_proj_pos.z < 1.0 &&
                    (vox_data & (1 << 30)) > 0 &&
                    abs((old_z - hit_view_pos.z) / hit_view_pos.z) < 0.05
                ) {
                    vox_hit = false;
                    real_sampled_dir = _real_sampled_dir;
                }
            }
        }
    }

    if (!hit) return false;

    // Construct hit material
    {
        vec3 ao = vec3(1.0);
        vec3 view_normal;

        if (vox_hit)
        {
            bool vox_emmisive = (vox_data & (1 << 29)) > 0;

            mat.albedo = fromGamma(unpackUnorm4x8(vox_data).rgb);
            mat.lmcoord = vec2(0.0, pow(vox_lmcoord_approx, 5.0));
            mat.roughness = 0.9;
            mat.metalic = 0.0;
            mat.flag = vox_emmisive ? -1.0 : 0.0;

            view_normal = mat3(gbufferModelView) * vox_hit_normal;

            hit_iuv = ivec2(-1);
        }
        else
        {
            vec3 albedo = texelFetch(colortex6, hit_pos, 0).rgb;

            vec4 normal_flag_encoded = texelFetch(colortex7, hit_pos, 0);
            vec4 lm_specular_encoded = texelFetch(colortex8, hit_pos, 0).rgba;

            mat.albedo = albedo;
            mat.lmcoord = pow(lm_specular_encoded.rg, vec2(5.0));
            mat.roughness = (1.0 - lm_specular_encoded.b);
            mat.metalic = lm_specular_encoded.a;
            mat.flag = normal_flag_encoded.a;

            view_normal = mat3(gbufferModelView) * normal_flag_encoded.rgb;

            hit_iuv = hit_pos;
        }
    }

    return true;
}

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * 2;
    ivec2 iuv_orig = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    float depth = texelFetch(colortex4, iuv_orig, 0).r;

    ivec2 halfscreen_offset = ivec2(viewWidth, viewHeight) >> 1;

#ifdef RAY_GUIDING
    weights[gl_LocalInvocationID.x][gl_LocalInvocationID.y] = texelFetch(colortex12, iuv_orig + halfscreen_offset, 0).r + 0.05;

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
        z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv_orig & 0xFF, 0).r * 65535.0) * 1000) ^ uint(11 * frameCounter);
        getRand();

        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);
        
        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        vec4 lm_specular_encoded = texelFetch(colortex8, iuv, 0).rgba;

        vec2 lmcoord = lm_specular_encoded.rg;

        float roughness = pow2(1.0 - lm_specular_encoded.b);
        float metalic = lm_specular_encoded.a;

        bool refine = roughness < 0.3;

        vec3 color = vec3(0.0);

        vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;

        float samples_taken = 0.0;

        if (texelFetch(colortex7, iuv, 0).a < 0.0) return;

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
            sample_dir = ImportanceSampleLambertian(rand2d, view_normal, pdf);
            selectPdf *= pdf;
#endif

#ifdef SPECULAR_ONLY
            if (roughness > 0.4) continue;
            sample_dir = ImportanceSampleBeckmann(rand2d, view_normal, view_dir, roughness, pdf);
#endif


            if (dot(sample_dir, view_normal) <= 0.0)
            {
                // Bruh
                continue;
            }
            
            samples_taken++;

            // Trace Ray
            vec3 hit_view_pos;
            vec3 hit_wpos;
            Material mat;
            vec3 sample_rad;
            ivec2 hit_iuv;

            if (traceRayHybrid(iuv, view_pos, view_normal, sample_dir, world_pos, world_normal, true, lmcoord.y, mat, hit_view_pos, hit_wpos, hit_iuv))
            {
                // Hit
                sample_rad = getLighting(mat, view_normal, sample_dir, hit_view_pos, hit_wpos, vec3(1.0));

#ifdef SPECULAR_ONLY
                if (hit_iuv != ivec2(-1))
                {
                    sample_rad = max(sample_rad, vec3(texelFetch(colortex2, hit_iuv, 0).rgb));
                }
#endif
            } else {
                // Skybox
                vec2 skybox_uv = project_skybox2uv(normalize(mat3(gbufferModelViewInverse) * sample_dir));

                float skybox_lod = pow(roughness, 0.25) * 5.0;

                int skybox_lod0 = int(floor(skybox_lod));
                int skybox_lod1 = int(ceil(skybox_lod));
                vec3 skybox_color = mix(
                    sampleLODmanual(colortex3, skybox_uv, skybox_lod0).rgb,
                    sampleLODmanual(colortex3, skybox_uv, skybox_lod1).rgb,
                    fract(skybox_lod));

                sample_rad = skybox_color;
            }


#ifdef SPECULAR_ONLY
            const bool do_specular = true;
#else
            const bool do_specular = false;
#endif
            sample_rad = BSDF(-view_dir, sample_dir, view_normal, metalic, roughness, albedo, do_specular) * sample_rad / selectPdf;
            color += sample_rad;

#ifdef RAY_GUIDING
            contributions[gl_LocalInvocationID.x][gl_LocalInvocationID.y][i] = dot(sample_rad, vec3(0.3, 0.6, 0.1));
#endif
        }

        // color /= max(0.001, samples_taken);

        if (isnan(color.r) || isnan(color.g) || isnan(color.b)) color = vec3(0.0);
        color = clamp(color, vec3(1e-5), vec3(1e4));

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
                    normalize_max = max(normalize_max, contributions[i][j][k]);
                }
            }
        }

        for (int i = 0; i < 8; i++)
        {
            for (int j = 0; j < 8; j++)
            {
                float last_contrib = texelFetch(colortex12, iuv_orig + halfscreen_offset + ivec2(i, j), 0).r;
                float new_contrib = weights[i][j] / normalize_max;
                new_contrib = max(last_contrib * 0.97, new_contrib);

                imageStore(colorimg5, iuv_orig + halfscreen_offset + ivec2(i, j), vec4(new_contrib, 0.0, 0.0, 1.0));
            }
        }

    }
#endif

#endif
}