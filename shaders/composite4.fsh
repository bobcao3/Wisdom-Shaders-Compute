#version 450 compatibility

#include "/libs/compat.glsl"

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

uniform usampler2D shadowcolor0;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"

#include "/configs.glsl"

uniform sampler2D shadowtex1;

vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness)
{
    float a = roughness;
	
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
	
    // from spherical coordinates to cartesian coordinates
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    // from tangent-space vector to world-space sample vector
    vec3 up        = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent   = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);
	
    vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
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
    float LdotV = dot(lightDirection, viewDirection);
    float NdotL = dot(lightDirection, surfaceNormal);
    float NdotV = dot(surfaceNormal, viewDirection);

    float s = LdotV - NdotL * NdotV;
    float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

    float sigma2 = roughness * roughness;
    vec3 A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    return albedo * max(vec3(subsurface), NdotL * (A + B * s / t)) / PI;
}

/* RENDERTARGETS: 2,12 */

float gaussian[] = float[] (
    0.06136, 0.24477, 0.38774, 0.24477, 0.06136
);

#include "/libs/voxelize.glslinc"

struct Ray
{
    vec3 o;
    vec3 d;
    vec3 invd;
    float maxT;
    float minT;
};

bool intersect_bbox(in Ray r, vec3 minp, vec3 maxp, out float maxT)
{
    vec3 vt0 = (minp - r.o) * r.invd;
    vec3 vt1 = (maxp - r.o) * r.invd;

    vec3 vtmin = min(vt0, vt1);
    vec3 vtmax = max(vt0, vt1);

    float tmin = max(vtmin.x, max(vtmin.y, vtmin.z));
    float tmax = min(vtmax.x, max(vtmax.y, vtmax.z));

    if (tmax >= tmin && tmin <= r.maxT && tmax >= r.minT)
    {
        maxT = tmin;
        return true;
    }

    return false;
}

const int MAX_RAY_STEPS = 128;

bool getVoxel(ivec3 volumePos)
{
    ivec2 planar_pos = volume2planar(volumePos + ivec3(volume_width, volume_depth, volume_height) / 2, 0);

    if (planar_pos == ivec2(-1)) return false;

    int voffset = 0;

    return texelFetch(shadowcolor0, planar_pos + ivec2(0, voffset), 0).r == 1;
}

uint getVoxelData(ivec3 volumePos, int lod)
{
    int stride = 1 << lod;

    ivec2 planar_pos = volume2planar(volumePos + (ivec3(volume_width, volume_depth, volume_height) >> (lod + 1)), lod);

    if (planar_pos == ivec2(-1)) return 0;

    int voffset = int(floor(shadowMapResolution * (1.0 - pow(0.5, lod))));

    return texelFetch(shadowcolor0, planar_pos + ivec2(0, voffset), 0).r;
}

uint getVoxelDataLight(ivec3 volumePos, int lod)
{
    ivec2 planar_pos = volume2planar(volumePos, lod);

    if (planar_pos == ivec2(-1)) return 0;

    int voffset = int(floor(shadowMapResolution * (1.0 - pow(0.5, lod))));
    int hoffset = (lod > 0) ? shadowMapResolution / 2 : 0;

    return texelFetch(shadowcolor0, planar_pos + ivec2(hoffset, voffset), 0).r;
}

bool voxel_march(vec3 rayPos, vec3 rayDir, float tMax, out vec3 hitNormal, out vec3 hitPos)
{
    rayPos += mod(cameraPosition, 1.0);

    vec3 pos = floor(rayPos);
	vec3 ri = 1.0 / rayDir;
	vec3 rs = sign(rayDir);
	vec3 dis = (pos - rayPos + 0.5 + rs * 0.5) * ri;
	
	float res = -1.0;
	vec3 mm = vec3(0.0);
	for( int i=0; i < MAX_RAY_STEPS; i++ ) 
	{
		if (getVoxel(ivec3(pos))) { res=1.0; break; }
		mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
		dis += mm * rs * ri;
        pos += mm * rs;
	}

	vec3 nor = -mm*rs;
	vec3 vos = pos;
	
    // intersect the cube	
	vec3 mini = (pos - rayPos + 0.5 - 0.5 * vec3(rs)) * ri;
	float t = max(mini.x, max(mini.y, mini.z));
	
    t = t * res;

	hitNormal = mm;
	hitPos = rayPos + t * rayDir - mod(cameraPosition, 1.0);

    if (dot(hitNormal, rayDir) > 0.0) hitNormal = -hitNormal; // Always keep the normal facing away from the ray direction.

	return (t > 0.0 && t < tMax);
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

vec3 randomCosineWeightedHemispherePoint(vec2 rand, vec3 n, out float pdf) {
    float r = sqrt(rand.x);
    float theta = 2.0 * 3.1415926 * rand.y;
    
    vec3 ph = vec3(r * cos(theta), r * sin(theta), sqrt(1.0 - rand.x));

    pdf = sqrt(1.0 - rand.x) / PI;

    return make_coord_space(n) * ph;
}

vec3 randomSphere(vec2 rand2d)
{
    float z = rand2d.y * 2.0 - 1.0;
    float sinTheta = sqrt(1.0 - z * z);
    float phi = rand2d.x * 3.1415926 * 2.0;
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, z);
}

#include "/libs/noise.glsl"

// Decent uniform RNG
// https://developer.nvidia.com/gpugems/gpugems3/part-vi-gpu-computing/chapter-37-efficient-random-number-generation-and-application
uint z1, z2, z3, z4;

// S1, S2, S3, and M are all constants, and z is part of the
// private per-thread generator state.
uint TausStep(uint z, uint S1, uint S2, uint S3, uint M) {
    uint b = (((z << S1) ^ z) >> S2);
    z = (((z & M) << S3) ^ b);
    return z;
}

// A and C are constants
uint LCGStep(uint z, uint A, uint C) {
    z = (A * z + C);
    return z;
}

float getRand() {
    // Combined period is lcm(p1,p2,p3,p4)~ 2^121
    z1 = TausStep(z1, 13, 19, 12, 4294967294); // p1=2^31-1
    z2 = TausStep(z2, 2, 25, 4, 4294967288);   // p2=2^30-1
    z3 = TausStep(z3, 3, 11, 17, 4294967280);  // p3=2^28-1
    z4 = LCGStep(z4, 1664525, 1013904223);     // p4=2^32
    return 2.3283064365387e-10 * float(z1 ^ z2 ^ z3 ^ z4);
}

bool coin_toss()
{
    z4 = (1103515245 * z4 + 12345) & 0x7FFFFFFF;
    return z4 >= 0x40000000;
}

ivec4 gselect;

ivec3 selectLight(out float pdf, vec3 world_pos, vec3 world_normal)
{
    ivec3 p = ivec3(0);

    pdf = 1.0;

    bool found = true;

    // 8 LODs
    for (int i = 8; i > 0; i--)
    {
        int s = 1 << (i - 1);

        bool validTree[2][2][2];
        float weights[2][2][2];

        float totalValids = 0.0;

        for (int x = 0; x < 2; x++)
        {
            for (int y = 0; y < 2; y++)
            {
                for (int z = 0; z < 2; z++)
                {
                    ivec3 testP = p + ivec3(s) * ivec3(x, y, z);

                    uint voxdata = getVoxelDataLight(testP, i - 1);

                    bool is_light = (i == 1) ? voxdata == 2 : ((voxdata & 0xFFFFF) > 0);

                    float weight = float(is_light);

                    if (i > 1) weight *= float(voxdata & 0xFFFFF);

                    // if (i < 7)
                    // {
                        vec3 testPcenter = (vec3(testP) + vec3(s) * 0.5);
                        vec3 testPvec = testPcenter - world_pos;
                        float angle = dot(world_normal, normalize(testPvec)) * 0.5 + 0.5;

                        weight *= angle;
                        weight /= dot(testPvec, testPvec);
                    // }

                    totalValids += weight;

                    validTree[x][y][z] = is_light;
                    weights[x][y][z] = weight;
                }
            }
        }

        float rand = getRand() * totalValids;

        bool found = false;

        // pdf /= totalValids;

        for (int x = 0; x < 2 && !found; x++)
        {
            for (int y = 0; y < 2 && !found; y++)
            {
                for (int z = 0; z < 2 && !found; z++)
                {
                    if (validTree[x][y][z])
                    {
                        float weight = weights[x][y][z];
                        rand -= weight;

                        if (rand <= 0.0)
                        {
                            p = p + ivec3(s) * ivec3(x, y, z);
                            found = true;
                            pdf *= weight / totalValids;
                        }
                    }
                }
            }
        }

    }

    return found ? p - ivec3(volume_width, volume_depth, volume_height) / 2 : ivec3(-10000);
}

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    float depth = texelFetch(depthtex0, iuv, 0).r;

    vec3 color = texelFetch(colortex2, iuv, 0).rgb;
    vec3 temporal = vec3(0.0);

    // color *= 0.0;

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;
        vec3 view_normal = texelFetch(colortex7, iuv, 0).rgb;

        vec3 indirect = vec3(0.0);
        float weight = 0.0001;

        for (int i = -1; i <= 1; i++)
        {
            for (int j = -1; j <= 1; j++)
            {
                vec3 sample_normal = texelFetch(colortex7, iuv + ivec2(i * 2, j * 2), 0).rgb;
                float sample_weight = gaussian[i + 2] * gaussian[j + 2] * pow3(abs(dot(sample_normal, view_normal)));
                indirect += texelFetch(colortex5, iuv / 2 + ivec2(i, j), 0).rgb * sample_weight;
                weight += sample_weight;
            }
        }

        indirect /= weight;

        vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;
        vec3 history = texture(colortex12, history_uv).rgb;

        if (isnan(history.x)) history = vec3(0.0);

        indirect = mix(history, indirect, 0.1);

        temporal = indirect;

        color += indirect * albedo;

        // Voxelization experiments
        /*
        color = vec3(0.0);

        #define PT_ALBEDO vec3(0.8)
        #define PT_TERMINATION_PROBABILITY 0.3

        vec3 world_normal = mat3(gbufferModelViewInverse) * vec3(view_normal);

        z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, ivec2(gl_FragCoord.st) & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);
        getRand();

        // This is the single path version of a bidirecional path tracer
        // You many want to use the tree / graph version where all possible connections are tested
        // Although the tree version produces much much much better quality for each sample
        // It is also geomtrically harder to do
        // Since we are running all of these in a shaders, register space is precious, therefore we will be avoiding a tree / graph
        #define NUM_LIGHT_BOUNCE 5
        #define NUM_EYE_BOUNCE 0

        vec2 rand2d = vec2(getRand(), getRand());
        vec3 randSphere = randomSphere(rand2d);

        float pdf;
        ivec3 ilightPos = selectLight(pdf, world_pos, world_normal);
        vec3 lightPos = vec3(ilightPos) - mod(cameraPosition, 1.0) + vec3(0.5) + randSphere * 0.2;

        vec3 lightRadiance = vec3(100.0);

        vec3 rayDir = vec3(0.0); // There is no direction for the very first vertex (it's on the light source!)
        vec3 hitNormal = randSphere; // We keep the normal since our light source is a sphere, where every point on the sphere emits light
        ivec3 lightFinalVoxel = ilightPos;

        for (int depth = 0; depth < NUM_LIGHT_BOUNCE; depth++)
        {
            // Russian roulette, randomly terminate the light path
            pdf *= 1.0 - PT_TERMINATION_PROBABILITY;
            if (getRand() < PT_TERMINATION_PROBABILITY)
            {
                break;
            }
            else if (depth != 0)
            {
                // Multiply the BSDF of this vertex
                float NdotL = abs(dot(rayDir, hitNormal));
                lightRadiance *= NdotL * PT_ALBEDO / 3.1415926;
            }

            rand2d = vec2(getRand(), getRand());
            if (depth == 0)
            {
                rayDir = randomSphere(rand2d);
                pdf *= 1.0 / (2.0 * PI);
            }
            else
            {
                float samplePDF;
                rayDir = randomCosineWeightedHemispherePoint(rand2d, hitNormal, samplePDF); pdf *= samplePDF;
            }

            vec3 hitPos;
            if (!voxel_march(lightPos + hitNormal * 0.05, rayDir, 10000.0, hitNormal, hitPos))
            {
                // Path failed, hit nothing
                lightRadiance = vec3(0.0);
                break;
            }

            // Next iteration
            lightPos = hitPos;
        }

        vec3 bsdfMultiplier = vec3(1.0);

        vec3 eyeRayDir = normalize(world_pos);

        vec3 Lout = vec3(0.0);

        // #define TREE_RESOLVE

        #ifdef TREE_RESOLVE
        for (int depth = 0; depth <= NUM_EYE_BOUNCE; depth++)
        #else
        for (int depth = 0; depth < NUM_EYE_BOUNCE; depth++)
        #endif
        {
            #ifdef TREE_RESOLVE
            {
                vec3 connection = lightPos - world_pos;
                vec3 connectionDir = normalize(connection);
                
                vec3 _temp;
                if (!voxel_march(world_pos + world_normal * 0.05, connectionDir, distance(lightPos, world_pos) - 0.01, _temp, _temp))
                {
                    // We have a valid connection between the two final vertices.
                    
                    // First compute the irradiance from end of light path to the end of light path
                    vec3 Lin = lightRadiance;
                    if (rayDir != vec3(0.0))
                    {
                        // There is only an BSDF if we actually left the light source
                        Lin *= abs(dot(hitNormal, rayDir)) * (PT_ALBEDO / PI); // Diffuse BSDF = albedo / PI
                    }

                    float pathPDF = pdf * dot(connection, connection); // The probabilty of some energy transferred from light path end point to eye path end point

                    // Then compute the BSDF at the end of light path, and computing the final irradiance Lout
                    // pathPDF *= 1.0 / PI; // Diffuse BSDF, the probability of having a outgoing ray towards connectionDir is 1.0 / PI
                    Lout += Lin * abs(dot(world_normal, connectionDir)) * bsdfMultiplier * (PT_ALBEDO / PI) / pathPDF;
                }
            }

            if (depth == NUM_EYE_BOUNCE) break;
            #endif

            // Russian roulette, randomly terminate the eye path
            pdf *= 1.0 - PT_TERMINATION_PROBABILITY;
            if (getRand() < PT_TERMINATION_PROBABILITY)
            {
                break;
            }

            rand2d = vec2(getRand(), getRand());
            float samplePDF;
            eyeRayDir = randomCosineWeightedHemispherePoint(rand2d, world_normal, samplePDF); pdf *= samplePDF;

            vec3 hitPos;
            if (!voxel_march(world_pos + world_normal * 0.01, eyeRayDir, 10000.0, world_normal, hitPos))
            {
                bsdfMultiplier = vec3(0.0); // Sad story, hit nothing
                break;
            }

            world_pos = hitPos;

            // Compute the BSDF until this point.
            vec3 bsdf = PT_ALBEDO / 3.1415926;

            float NdotL = abs(dot(eyeRayDir, world_normal));
            bsdfMultiplier *= NdotL * bsdf;
        }

        // Making the final connection
        // The light path ends at lightPos, with surface normal hitNormal, with radiance of lightRadiance
        // The eye path ends at world_pos, with surface normal world_normal
        #ifndef TREE_RESOLVE
        vec3 connection = lightPos - world_pos;
        vec3 connectionDir = normalize(connection);

        vec3 _temp;
        if (!voxel_march(world_pos + world_normal * 0.005, connectionDir, distance(lightPos, world_pos) - 0.005, _temp, _temp))
        {
            // We have a valid connection between the two final vertices.
            
            // First compute the irradiance from end of light path to the end of light path
            vec3 Lin = lightRadiance;
            if (rayDir != vec3(0.0))
            {
                // There is only an BSDF if we actually left the light source
                Lin *= max(0.0, dot(hitNormal, -rayDir)) * (PT_ALBEDO / PI); // Diffuse BSDF = albedo / PI
                Lin *= abs(dot(hitNormal, -connectionDir));
            }
            else
            {
                //pdf *= PI;
            }
            
            pdf *= dot(connection, connection); // The probabilty of some energy transferred from light path end point to eye path end point

            // Then compute the BSDF at the end of light path, and computing the final irradiance Lout
            float NdotL = max(0.0, dot(world_normal, connectionDir));
            vec3 bsdf = bsdfMultiplier * NdotL * (PT_ALBEDO / PI);
            Lout = Lin * bsdf / pdf;
        }

        // Lout = vec3(0.0);
        // if (length(connection) < 0.1) Lout = vec3(1000.0);
        #endif

        color = Lout;
        */

    }
    else
    {
        //color = vec3(0.0);
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(temporal, 1.0);
}