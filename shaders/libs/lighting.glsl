#define LIGHTING_SAMPLES 4 // [4 8 16]

float oren_nayer(in vec3 v, in vec3 l, in vec3 n, in float r) {
	float NdotL = clamp(dot(n, l), 0.0, 1.0);
	float NdotV = clamp(dot(n, v), 0.0, 1.0);

	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return NdotL * (b * c + a);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow5(max(1.0 - cosTheta, 0.001));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow5(1.0 - cosTheta);
}

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(float NdotV, float NdotL, float k) {
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
	float a      = roughness*roughness;
	float a2     = a*a;
	float NdotH  = abs(dot(N, H));

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;

	return a2 / denom;
}

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

//	roughness = clamp(roughness, 0.00001, 0.999999);

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

bool match(float a, float b)
{
	return (a > b - 0.002 && a < b + 0.002);
}

vec3 getF(float metalic, float roughness, float cosTheta, vec3 albedo)
{
	if (metalic < (229.5 / 255.0))
    {
        float metalic_generated = 1.0 - metalic * (229.0 / 255.0);
        metalic_generated = pow(metalic_generated, 2.0);
		return fresnelSchlickRoughness(cosTheta, vec3(metalic_generated), roughness) * albedo;
    }

	#include "/programs/post/materials.glsl"

	cosTheta = max(0.01, abs(cosTheta));

	vec3 NcosTheta = 2.0 * N * cosTheta;
	float cosTheta2 = cosTheta * cosTheta;
	vec3 N2K2 = N * N + K * K;

	vec3 Rs = (N2K2 - NcosTheta + cosTheta2) / (N2K2 + NcosTheta + cosTheta2);
	vec3 Rp = (N2K2 * cosTheta2 - NcosTheta + 1.0) / (N2K2 * cosTheta2 + NcosTheta + 1.0);

	return (Rs + Rp) * 0.5 * albedo;
}

vec3 brdf_ggx_oren_schlick(vec3 albedo, vec3 radiance, float roughness, float metalic, float subsurface, vec3 F, vec3 L, vec3 N, vec3 V)
{
	vec3 H = normalize(vec3(L + V));
	float NDF = float(DistributionGGX(N, H, roughness));
	float G = float(oren_nayer(V, L, N, roughness));

	vec3 kD = vec3(float(1.0) - float(metalic));
	
	float NdotL = min(1.0, float(max(0.0, dot(N, L)) + float(subsurface * 0.3)));                
	
	vec3 numerator    = NDF * G * F;
	float denominator = float(4.0) * max(NdotL, float(0.005)); // * max(float(dot(N, -V)), float(0.005));
	vec3 specular     = numerator / denominator;  
	
	return vec3(max(vec3(0.0), (kD * albedo / float(3.1415926) + specular) * radiance * NdotL));
}

vec3 diffuse_brdf_ggx_oren_schlick(vec3 albedo, vec3 radiance, float roughness, float metalic, vec3 F0, vec3 N, vec3 V)
{
	vec3 F = fresnelSchlickRoughness(max(0.0, dot(N, V)), F0, roughness);

	vec3 kS = F;
	vec3 kD = vec3(1.0) - kS;
	kD *= 1.0 - metalic;	  
	
	return kD * albedo / 3.1415926 * radiance;
}

vec3 specular_brdf_ggx_oren_schlick(vec3 radiance, float roughness, vec3 F0, vec3 L, vec3 N, vec3 V)
{
	vec3 H = normalize(L + V);
	float NDF = DistributionGGX(N, H, roughness);
	float G = oren_nayer(V, L, N, roughness);
	vec3 F = fresnelSchlickRoughness(max(0.0, dot(H, V)), F0, roughness);
	
	vec3 numerator    = NDF * G * F;
	float denominator = 4.0 * max(dot(N, V), 0.001) * max(dot(N, L), 0.001);
	vec3 specular     = numerator / denominator;  
	
	float NdotL = max(dot(N, L), 0.0);                
	return max(vec3(0.0), specular * radiance * NdotL); 
}

vec3 orenNayarDiffuse(vec3 lightDirection, vec3 viewDirection, vec3 surfaceNormal, float roughness, vec3 albedo, float subsurface) {  
    float LdotV = dot(lightDirection, viewDirection);
    float NdotL = dot(lightDirection, surfaceNormal);
    float NdotV = dot(surfaceNormal, viewDirection);

    float s = LdotV - NdotL * NdotV;
    float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

    float sigma2 = roughness * roughness;
    vec3 A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    return albedo * min(1.0, NdotL + subsurface * 0.5) * (A + B * s / t) / PI;
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
};

vec3 getLighting(Material mat, vec3 view_normal, vec3 view_dir, vec3 view_pos, vec3 world_pos, vec3 ao)
{
    vec3 color = vec3(0.0);

    // --------------------------------------------------------------------
    //  IBL + AO (Indirect)
    // --------------------------------------------------------------------

    float samples_taken = 0.0;

    vec3 image_based_lighting = vec3(0.0);

    for (int i = 0; i < LIGHTING_SAMPLES; i++)
    {
        vec2 rand2d = vec2(getRand(), getRand());

        float pdf;
        vec3 sample_dir = ImportanceSampleGGX(rand2d, view_normal, view_dir, mat.roughness, pdf);
        samples_taken++;

        if (dot(sample_dir, view_normal) <= 0.0)
        {
            rand2d = vec2(getRand(), getRand());
            sample_dir = ImportanceSampleGGX(rand2d, view_normal, view_dir, mat.roughness, pdf);
            samples_taken++;
        }

        if (dot(sample_dir, view_normal) <= 0.0)
        {
            // Bruh
            continue;
        }

        vec3 world_sample_dir = mat3(gbufferModelViewInverse) * sample_dir;

        vec2 skybox_uv = project_skybox2uv(world_sample_dir);

        float skybox_lod = pow(mat.roughness, 0.25) * 6.0;

        int skybox_lod0 = int(floor(skybox_lod));
        int skybox_lod1 = int(ceil(skybox_lod));
        vec3 skybox_color = mix(
            sampleLODmanual(colortex3, skybox_uv, skybox_lod0).rgb,
            sampleLODmanual(colortex3, skybox_uv, skybox_lod1).rgb,
            fract(skybox_lod));

        image_based_lighting += skybox_color * max(0.0, dot(view_normal, sample_dir));
    }

    image_based_lighting *= 1.0 / samples_taken;

    vec3 F = getF(mat.metalic, mat.roughness, abs(dot(view_dir, view_normal)), mat.albedo);
    image_based_lighting *= F;

    color += ((ao * smoothstep(0.1, 1.0, mat.lmcoord.y)) * image_based_lighting * 2.0);

    // --------------------------------------------------------------------
    //  Block-light
    // --------------------------------------------------------------------

    const vec3 blocklight_color = vec3(0.3, 0.2, 0.1);

    color += (mat.albedo / PI) * max(1.0 / (pow2(max(0.95 - mat.lmcoord.x, 0.0) * 6.0) + 1.0) - 0.05, 0.0) * blocklight_color;

    // --------------------------------------------------------------------
    //  Directional
    // --------------------------------------------------------------------

    float shadow_depth;

    vec3 shadow_pos_linear = world2shadowProj(world_pos) * 0.5 + 0.5;

    float shadow = shadowTexSmooth(shadow_pos_linear, shadow_depth, 0.0);

#ifdef SCREEN_SPACE_SHADOWS
    if (mat.flag < 0.1)
    {
        shadow = min(shadow, screen_space_shadows(view_pos, normalize(shadowLightPosition), getRand()));
    }
#endif
    
    vec3 sun_radiance = shadow * texelFetch(colortex3, ivec2(viewWidth - 1, 0), 0).rgb;

    color += brdf_ggx_oren_schlick(mat.albedo, sun_radiance, mat.roughness, mat.metalic, mat.flag, F, shadowLightPosition * 0.01, view_normal, view_dir);

    float shadow_depth_diff = max(shadow_pos_linear.z - shadow_depth, 0.0);

    // --------------------------------------------------------------------
    //  Emission
    // --------------------------------------------------------------------

    if (mat.flag < 0.0)
    {
        color = mat.albedo;
    }

    return color;
}