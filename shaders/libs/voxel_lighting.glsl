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

    return (texelFetch(shadowcolor0, planar_pos + ivec2(0, voffset), 0).r & (1 << 30)) > 0;
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

bool voxel_march(vec3 rayPos, vec3 rayDir, float tMax, out vec3 hitNormal, out vec3 hitPos, out uint data)
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
		if (getVoxel(ivec3(pos))) {
            res = 1.0;
            data = getVoxelData(ivec3(pos), 0);
            break;
        }
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

ivec4 gselect;

ivec3 selectLight(out float pdf, vec3 world_pos, vec3 world_normal, out vec3 lightColor)
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

                    vec4 voxcolor = unpackUnorm4x8(voxdata);

                    bool is_light = (i == 1) ? voxcolor.a > 0.5 : ((voxdata & 0xFFFFF) > 0);

                    float weight = float(is_light);

                    if (i > 1) weight *= float(voxdata & 0xFFFFF);

                    // if (i < 6)
                    // {
                    //     vec3 testPcenter = (vec3(testP) + vec3(s) * 0.5);
                    //     vec3 testPvec = testPcenter - world_pos;
                    //     float angle = dot(world_normal, normalize(testPvec)) * 0.5 + 0.5;

                    //     weight *= angle;
                    //     weight /= dot(testPvec, testPvec);
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

    if (found)
    {
        uint voxdata = getVoxelDataLight(p, 0);

        vec4 voxcolor = unpackUnorm4x8(voxdata);

        lightColor = voxcolor.rgb;
    }

    return found ? p - ivec3(volume_width, volume_depth, volume_height) / 2 : ivec3(-10000);
}

vec3 getVoxelLighting(vec3 world_normal, vec3 world_pos, ivec2 fragCoord)
{
    vec3 lighting = vec3(0.0);

    z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, fragCoord & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);
    getRand();

    #define NUM_DIRECT_LIGHTS 4

    for (int i = 0; i < NUM_DIRECT_LIGHTS; i++)
    {
        vec2 rand2d = vec2(getRand(), getRand());
        vec3 randSphere = randomSphere(rand2d);

        float pdf;
        vec3 lightRadiance = vec3(0.0);
        ivec3 ilightPos = selectLight(pdf, world_pos, world_normal, lightRadiance);
        vec3 lightPos = vec3(ilightPos) - mod(cameraPosition, 1.0) + vec3(0.5) + randSphere * 0.2;

        vec3 L = normalize(lightPos - world_pos);

        vec3 directLighting = lightRadiance * (max(0.0, dot(L, world_normal)) / (dot(lightPos - world_pos, lightPos - world_pos) * pdf));

        lighting += directLighting;
    }

    return lighting * (1.0 / float(NUM_DIRECT_LIGHTS));
}