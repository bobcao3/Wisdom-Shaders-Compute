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

uniform sampler2D shadowtex1;

mat3 make_coord_space(vec3 n) {
    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x = 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y = 1.0;
    else
        h.z = 1.0;

    vec3 y = normalize(cross(h, n));
    vec3 x = normalize(cross(n, y));

    return mat3(x, y, n);
}


vec3 ImportanceSampleGGX(vec2 rand, vec3 N, vec3 wo, float roughness, out float pdf)
{
	rand = clamp(rand, vec2(0.0001), vec2(0.9999));

	roughness = clamp(roughness, 0.00001, 0.999999);

	float tanTheta = roughness * sqrt(rand.x / (1.0 - rand.x));
	float theta = clamp(atan(tanTheta), 0.0, 3.1415926 * 0.5 - 0.2);
	float phi = 2.0 * 3.1415926 * rand.y;

	vec3 h = vec3(
		sin(theta) * cos(phi),
		sin(theta) * sin(phi),
		cos(theta)
	);

	h = make_coord_space(N) * h;

	float sin_h = abs(sin(theta));
	float cos_h = abs(cos(theta));

	vec3 wi = reflect(wo, h);

	pdf = (2.0 * roughness * roughness * cos_h * sin_h) / pow2((roughness * roughness - 1.0) * cos_h * cos_h + 1.0) / (4.0 * abs(dot(wo, h)));

	return wi;
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow5(max(1.0 - cosTheta, 0.001));
}

bool match(float a, float b)
{
	return (a > b - 0.002 && a < b + 0.002);
}

vec3 getF(float metalic, float roughness, float cosTheta)
{
	if (metalic < (229.5 / 255.0))
    {
        float metalic_generated = 1.0 - metalic * (229.0 / 255.0);
        metalic_generated = pow(metalic_generated, 2.0);
		return fresnelSchlickRoughness(cosTheta, vec3(metalic_generated), roughness);
    }

	#include "/programs/post/materials.glsl"

	cosTheta = max(0.01, abs(cosTheta));

	vec3 NcosTheta = 2.0 * N * cosTheta;
	float cosTheta2 = cosTheta * cosTheta;
	vec3 N2K2 = N * N + K * K;

	vec3 Rs = (N2K2 - NcosTheta + cosTheta2) / (N2K2 + NcosTheta + cosTheta2);
	vec3 Rp = (N2K2 * cosTheta2 - NcosTheta + 1.0) / (N2K2 * cosTheta2 + NcosTheta + 1.0);

	return (Rs + Rp) * 0.5;
}

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

float shadowTexSmooth(in sampler2D tex, in vec3 spos, out float depth, float bias) {
    if (clamp(spos, vec3(0.0), vec3(1.0)) != spos) return 1.0;

    return VSM(spos.z, spos.xy);
}

#define VL

#include "/libs/atmosphere.glsl"

vec3 orenNayarDiffuse(vec3 lightDirection, vec3 viewDirection, vec3 surfaceNormal, float roughness, vec3 albedo, float subsurface) {  
    float LdotV = max(0.0, dot(lightDirection, viewDirection));
    float NdotL = max(0.0, dot(lightDirection, surfaceNormal));
    float NdotV = max(0.0, dot(surfaceNormal, viewDirection));

    float s = LdotV - NdotL * NdotV;
    float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

    float sigma2 = roughness * roughness;
    vec3 A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    return albedo * max(vec3(subsurface), NdotL * (A + B * s / t)) / PI;
}

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
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        int lod = 3;

        vec2 noise_uv = vec2(iuv);
        float noise1d = bayer64(noise_uv);
        int noise_i = int(noise1d * 64 * 64 + (frameCounter & 0XFF));

        const float zThickness = 0.5;
        const float stride = 2.0;
        const float stride_multiplier = 1.3;
        
        vec3 view_normal = texelFetch(colortex7, iuv, 0).rgb;

        vec4 lm_specular_encoded = texelFetch(colortex8, iuv, 0).rgba;

        float roughness = (1.0 - lm_specular_encoded.b);
        // float metalic = lm_specular_encoded.a;

        bool refine = roughness < 0.3;

        vec3 color = vec3(0.0);

        vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;

        #define SSPT_RAYS 4 // [1 2 4 8 16]

        for (int i = 0; i < SSPT_RAYS; i++)
        {
            vec2 rand2d = fract(vec2(hash(noise_uv), hash(-noise_uv)) + WeylNth(i + (frameCounter & 0xFF)));

            float pdf;
            vec3 sample_dir = ImportanceSampleGGX(rand2d, view_normal, view_dir, roughness, pdf);
            // vec3 sample_dir = normalize(2.0 * dot(-view_dir, H) * H + view_dir);

            if (dot(sample_dir, view_normal) < 0.0)
            {
                sample_dir = reflect(sample_dir, view_normal);
            }

            ivec2 hit_pos = raytrace(view_pos + view_normal * 0.2, iuv, sample_dir, stride, stride_multiplier, zThickness, noise_i, lod, refine);

            if (hit_pos != ivec2(-1) && hit_pos != iuv)
            {
                vec3 hit_color = texelFetch(colortex2, hit_pos, 0).rgb;
                vec3 hit_proj_pos = getProjPos(hit_pos);
                vec3 hit_view_pos = proj2view(proj_pos);

                float dist_to_sample = distance(view_pos, hit_view_pos);
                float attenuation = 1.0; //1.0 - smoothstep(2.0, 4.0, dist_to_sample) * clamp(roughness * 3.0, 0.0, 1.0);

                color += clamp(hit_color, vec3(0.0), vec3(3.0)) * attenuation * max(0.0, dot(sample_dir, view_normal));
            }
        }

        color *= (1.0 / float(SSPT_RAYS));

        vec3 world_normal = mat3(gbufferModelViewInverse) * vec3(view_normal);

        // color += getVoxelLighting(world_normal, world_pos, iuv_orig);

        imageStore(colorimg5, iuv_orig, vec4(color, 1.0));
    }
#endif
}