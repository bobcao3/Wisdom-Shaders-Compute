#define LIGHTING_SAMPLES 1 // [4 8 16]

mat3 make_coord_space(const vec3 n) {
    const vec3 h = (abs(n.y) > 0.9) ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);

    const vec3 y = normalize(cross(h, n));
    const vec3 x = cross(n, y);

    return mat3(x, y, n);
}

vec3 ImportanceSampleGGX(vec2 rand, vec3 N, vec3 wo, float roughness, out float pdf)
{
	// rand = clamp(rand, vec2(0.0001), vec2(0.9999));

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

vec3 ImportanceSampleLambertian(vec2 rand, vec3 N, out float pdf)
{
    float r = sqrt(rand.x);
    float theta = 2.0f * 3.14159265f * rand.y;
    
    pdf = sqrt(1 - rand.x) / 3.14159265f;

    return make_coord_space(N) * vec3(r * cos(theta), r * sin(theta), sqrt(1 - rand.x));
}

/*
float erf_guts(float x) {
    const float M_PI = 3.1415926535;
    const float a = 8.0 * (M_PI - 3.0) / (3.0 * M_PI * (4.0 - M_PI));

    float x2 = x * x;
    return exp(-x2 * (4.0 / M_PI + a * x2) / (1.0 + a * x2));
}

float erf(float x) {
   return sign(x) * sqrt(1.0 - erf_guts(x));
}
*/

float erf(float x) {
  float s = sign(x), a = abs(x);
  x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
  x *= x;
  return s - s / (x * x);
}

float getTheta(vec3 v, vec3 n)
{
    return acos(clamp(dot(v, n), -1.0 + 1e-5, 1.0 - 1e-5));
}

float getTheta(vec3 v)
{
    return acos(clamp(v.z, -1.0 + 1e-5, 1.0 - 1e-5));
}

// float lambda(float theta, float alpha)
// {
//     float a = 1.0 / (alpha * tan(theta));
//     return 0.5 * (erf(a) - 1.0 + exp(-pow2(a)) / (a * sqrt(PI)));
// }

// https://www.pbr-book.org/3ed-2018/Reflection_Models/Microfacet_Models BeckmannDistribution::Lambda
float lambda(float theta, float alpha)
{
    float absTanTheta = abs(tan(theta));
    if (isNanInf(absTanTheta)) return 0.0;
    float a = 1.0 / (alpha * absTanTheta);
    if (a >= 1.6) return 0.0;
    return (1.0 - 1.259 * a + 0.396 * a * a) /
           (3.535 * a + 2.181 * a * a);
}

// https://www.pbr-book.org/3ed-2018/Reflection_Models/Microfacet_Models Microfacet Distribution G
float BSDF_G(vec3 v, vec3 l, float alpha)
{
    return 1.0 / (1.0 + lambda(getTheta(v), alpha) + lambda(getTheta(l), alpha));
}

// https://www.pbr-book.org/3ed-2018/Reflection_Models/Microfacet_Models BeckmannDistribution::D
float BSDF_D_theta_h(float theta_h, float alpha)
{
    return exp(-pow2(tan(theta_h)) / max(1e-5, pow2(alpha))) / max(1e-5, PI * pow2(alpha) * pow4(cos(theta_h)));
}

float BSDF_D(vec3 h, float alpha)
{
    float theta_h = getTheta(h);
    return BSDF_D_theta_h(theta_h, alpha);
}

vec3 ImportanceSampleBeckmann(vec2 rand, vec3 N, vec3 wo, float alpha, out float pdf)
{
    float theta_h = atan(sqrt(max(0.0, -alpha * alpha * log(1.0 - rand.x))));
    float phi_h = rand.y * PI * 2.0;

    vec3 h = vec3(sin(theta_h) * cos(phi_h), sin(theta_h) * sin(phi_h), cos(theta_h));
    vec3 world_h = make_coord_space(N) * h;
    vec3 wi = reflect(-wo, world_h);

    float cos_theta_h = clamp(h.z, 0.0, 1.0);
    float sin_theta_h = sqrt(1.0 - pow2(cos_theta_h));

    float pdfTheta = PI * 2.0 * BSDF_D_theta_h(theta_h, alpha) * sin_theta_h * cos_theta_h / (4.0 * dot(wi, world_h));
    float pdfPhi = 1.0 / (PI * 2.0);
    pdf = (pdfTheta * pdfPhi / sin_theta_h);

    if (alpha < 0.01) pdf = 1.0;

    return wi;
}

bool match(float a, float b)
{
	return (a > b - 0.002 && a < b + 0.002);
}

vec3 MetalF(float metalic, float cosTheta)
{
	#include "/programs/post/materials.glsl"

	vec3 NcosTheta = 2.0 * N * cosTheta;
	float cosTheta2 = cosTheta * cosTheta;
	vec3 N2K2 = N * N + K * K;

	vec3 Rs = (N2K2 - NcosTheta + cosTheta2) / max(vec3(1e-5), N2K2 + NcosTheta + cosTheta2);
	vec3 Rp = (N2K2 * cosTheta2 - NcosTheta + 1.0) / max(vec3(1e-5), N2K2 * cosTheta2 + NcosTheta + 1.0);

	return (Rs + Rp) * 0.5;
}

vec3 getF0(float metalic)
{
    float metalic_generated = clamp(1.0 - metalic * (229.0 / 255.0), 0.0, 0.98);
    return vec3(1.0 - metalic_generated);
}

float orenNayarDiffuse(float LdotV, float NdotL, float NdotV, float albedo, float roughness)
{
  float s = LdotV - NdotL * NdotV;
  float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

  float sigma2 = roughness * roughness;
  float A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
  float B = 0.45 * sigma2 / (sigma2 + 0.09);

  return max(0.0, NdotL) * (A + B * s / t) / PI;
}

vec3 BSDF(vec3 wo, vec3 wi, vec3 N, float metalic, float alpha, vec3 albedo, bool do_specular, out vec3 kD)
{
    const mat3 o2w = make_coord_space(N);
    const mat3 w2o = transpose(o2w);

    wo = w2o * wo;
    wi = w2o * wi;

    vec3 h = normalize(wo + wi);

    if (wo.z <= 0.0) return vec3(0.0);
    if (wi.z <= 0.0) return vec3(0.0);

    float G = BSDF_G(wo, wi, alpha);
    float D = BSDF_D(h, alpha);

    if (metalic > (229.5 / 255.0))
    {
        // Metals
        vec3 F = MetalF(metalic, abs(wi.z));

#ifdef DIFFUSE_ONLY
        return vec3(0.0);
#elif defined(SPECULAR_ONLY)
        return F * G;
#else
        return F * G * D;
#endif
    } else {
        // Non-metals
        vec3 F0 = getF0(metalic);

        vec3 F = F0 + pow5(1.0 - abs(dot(wo, h))) * (1.0 - F0);

        vec3 kS = F;
        kD = 1.0 - kS;
        kD *= 1.0 - F0.r;

        vec3 diffuse = kD * orenNayarDiffuse(dot(wo, wi), wi.z, wo.z, kD.y, alpha);

        vec3 specular = F * G / max(0.001, 4.0 * abs(wo.z));

#ifdef SPECULAR_ONLY
        return do_specular ? specular : diffuse;
#elif defined(DIFFUSE_ONLY)
        return do_specular ? specular * D + diffuse : diffuse;
#else
        return specular * D + diffuse;
#endif
    }
}

float screen_space_shadows(vec3 view_pos, vec3 view_dir, float nseed)
{
    float step_length = 0.03;

    // if (view_pos.z < -20.0) return 1.0;

    float last_z = view_pos.z;

    for (int i = 0; i < 6; i++)
    {
        float step_i = (float(i) + nseed + 0.2);
        vec3 raymarch_pos = view_pos + view_dir * step_length * step_i;

        vec3 proj_pos = view2proj(raymarch_pos);
        vec2 proj_uv = proj_pos.st * 0.5 + 0.5;

        float depth = texture(depthtex0, proj_uv).r;
        vec3 actual_proj_pos = getProjPos(proj_uv, depth);
        vec3 actual_view_pos = proj2view(actual_proj_pos);

        float z0, z1, expected_z = raymarch_pos.z;

        if (last_z > expected_z)
        {
            z0 = expected_z;
            z1 = last_z;
        }
        else
        {
            z1 = raymarch_pos.z;
            z0 = last_z;
        }

        if ((actual_view_pos.z > expected_z - view_pos.z * 0.001) && (actual_view_pos.z < expected_z + 0.05 + step_length * 2.0))
        {
            return smoothstep(3.0, 7.0, step_i) * 0.9 + 0.1;
        }

        last_z = raymarch_pos.z;
    }

    return 1.0;
}

struct Material
{
    vec3 albedo;
    vec2 lmcoord;
    float roughness;
    float metalic;
    float flag;
    vec3 view_normal;
};

vec3 getLighting(Material mat, vec3 view_dir, vec3 view_pos, vec3 world_pos, const vec3 ao)
{
    vec3 color = vec3(0.0);

    // --------------------------------------------------------------------
    //  IBL + AO (Indirect)
    // --------------------------------------------------------------------

    float samples_taken = 0.0;

    vec3 image_based_lighting = vec3(0.0);
    
    #ifdef INCLUDE_IBL

    for (int i = 0; i < LIGHTING_SAMPLES; i++)
    {
        vec2 rand2d = vec2(getRand(), getRand());

        float lobe_selection = getRand();
        float selectPdf = 1.0;

        vec3 sample_dir;

        float lumaF0 = mat.metalic < (229.5 / 255.0) ? mat.roughness : 0.0;

        if (getRand() < lumaF0)
        {
            float pdf;
            sample_dir = ImportanceSampleLambertian(rand2d, mat.view_normal, pdf);
            selectPdf *= pdf * lumaF0;
        } else {
            float pdf;
            sample_dir = ImportanceSampleBeckmann(rand2d, mat.view_normal, -view_dir, mat.roughness, pdf);
            selectPdf *= pdf * (1.0 - lumaF0);
        }

        if (dot(sample_dir, mat.view_normal) <= 0.0)
        {
            // Bruh
            continue;
        }

        samples_taken++;

        vec3 world_sample_dir = mat3(gbufferModelViewInverse) * sample_dir;

        vec2 skybox_uv = project_skybox2uv(world_sample_dir);

        float skybox_lod = pow(mat.roughness, 0.25) * 6.0;

        int skybox_lod0 = int(floor(skybox_lod));
        int skybox_lod1 = int(ceil(skybox_lod));
        vec3 skybox_color = mix(
            sampleLODmanual(colortex3, skybox_uv, skybox_lod0).rgb,
            sampleLODmanual(colortex3, skybox_uv, skybox_lod1).rgb,
            fract(skybox_lod));

        vec3 _kd;
        image_based_lighting += BSDF(-view_dir, sample_dir, mat.view_normal, mat.metalic, mat.roughness, mat.albedo, false, _kd) * mat.albedo * skybox_color / max(0.001, selectPdf);
    }

    image_based_lighting *= 1.0 / max(samples_taken, 0.01);

    color += smoothstep(0.1, 1.0, mat.lmcoord.y) * image_based_lighting;

    #endif

    // --------------------------------------------------------------------
    //  Block-light
    // --------------------------------------------------------------------

// #ifdef SSPT
//     const vec3 blocklight_color = vec3(0.1, 0.08, 0.06);
// #else
    const vec3 blocklight_color = vec3(0.3, 0.2, 0.1);
// #endif
    
    color += smoothstep(float(128) * 0.7, float(128), length(view_pos)) * mat.albedo * max(1.0 / (pow2(max(0.95 - mat.lmcoord.x, 0.0) * 6.0) + 1.0) - 0.05, 0.0) * blocklight_color * ao;

    // --------------------------------------------------------------------
    //  Directional
    // --------------------------------------------------------------------

    vec3 sun_radiance = vec3(0.0);

    if (dot(shadowLightPosition, mat.view_normal) >= 0.0)
    {
        float shadow_depth;

        vec3 shadow_pos_linear = world2shadowProj(world_pos) * 0.5 + 0.5;

        float shadow = shadowTexSmooth(shadow_pos_linear, shadow_depth, 1e-4 * (1.0 + length(shadow_pos_linear.xy) * 8.0));

#ifdef SCREEN_SPACE_SHADOWS
        if (mat.flag < 0.1)
        {
            shadow = min(shadow, screen_space_shadows(view_pos, normalize(shadowLightPosition), getRand()));
        }
#endif
        
        sun_radiance = shadow * texelFetch(colortex3, ivec2(viewWidth - 1, 0), 0).rgb;
    }

    // FIXME: SSS
    vec3 _kd;
    color += BSDF(-view_dir, shadowLightPosition * 0.01, mat.view_normal, mat.metalic, mat.roughness, mat.albedo, false, _kd) * sun_radiance * mat.albedo;

    // --------------------------------------------------------------------
    //  Emission
    // --------------------------------------------------------------------

    color = max(vec3(0.0), color);

    if (mat.flag < 0.0)
    {
        color += mat.albedo;
    }

    return color;
}