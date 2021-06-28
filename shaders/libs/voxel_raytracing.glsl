#include "/libs/voxelize.glslinc"

bool intersect_bbox(vec3 o, vec3 invd, vec3 minp, vec3 maxp, out float t)
{
    vec3 vt0 = (minp - o) * invd;
    vec3 vt1 = (maxp - o) * invd;

    vec3 vtmin = min(vt0, vt1);
    vec3 vtmax = max(vt0, vt1);

    float tmin = max(vtmin.x, max(vtmin.y, vtmin.z));
    float tmax = min(vtmax.x, min(vtmax.y, vtmax.z));

    if (tmax >= tmin && (tmin > 0.0 || tmax > 0.0))
    {
        t = (tmin > 0) ? tmin : tmax;
        return true;
    }

    return false;
}

const int MAX_RAY_STEPS = 64;

// shape_cube = 0
// shape_bottom_slab = 1
// shape_top_slab = 2
// shape_sheet = 3
// shape_sphere = 5
// shape_transparent = 6 # No interaction with the ray
// shape_translucent = 7 # Color gets tinted

bool voxIsCube(uint d) { return (d >> 29) == 0; }
bool voxIsBottomSlab(uint d) { return (d >> 29) == 1; }
bool voxIsTopSlab(uint d) { return (d >> 29) == 2; }
bool voxIsSheet(uint d) { return (d >> 29) == 3; }
bool voxIsColumn(uint d) { return (d >> 29) == 4; }
bool voxIsSphere(uint d) { return (d >> 29) == 5; }
bool voxIsTransparent(uint d) { return (d >> 29) == 6; }
bool voxIsTranslucent(uint d) { return (d >> 29) == 7; }

bool voxIsEmissive(uint d) { return (d & (1 << 28)) > 0; }

uint getVoxelData(ivec3 volumePos, out bool terminate)
{
    ivec2 planar_pos = volume2planar(volumePos + ivec3(volume_width, volume_depth, volume_height) / 2, 0);

    if (planar_pos == ivec2(-1))
    {
        terminate = true;
        return 0;
    }

    uint d = texelFetch(shadowcolor0, planar_pos, 0).r;

    terminate = false;
    return d;
}

uint getVoxelDataLight(ivec3 volumePos, int lod)
{
    ivec2 planar_pos = volume2planar(volumePos, lod);

    if (planar_pos == ivec2(-1)) return 0;

    int voffset = int(floor(shadowMapResolution * (1.0 - pow(0.5, lod))));
    int hoffset = (lod > 0) ? shadowMapResolution / 2 : 0;

    return texelFetch(shadowcolor0, planar_pos + ivec2(hoffset, voffset), 0).r;
}

bool voxel_march(vec3 rayPos, vec3 rayDir, float tMax, out vec3 hitNormal, out vec3 hitPos, out uint data, out vec3 tint)
{
    rayPos += mod(cameraPosition, 1.0);

    vec3 pos = floor(rayPos);
	vec3 ri = 1.0 / rayDir;
	vec3 rs = sign(rayDir);
	vec3 dis = (pos - rayPos + 0.5 + rs * 0.5) * ri;

    tint = vec3(1.0);

	float res = -1.0;
	vec3 mm = vec3(0.0);
    float t = 0.0;
	for(int i = 0; i < MAX_RAY_STEPS; i++) 
	{
        bool terminate;
        data = getVoxelData(ivec3(pos), terminate);

        if (terminate) return false;

        if (voxIsTranslucent(data))
        {
            tint *= fromGamma(unpackUnorm4x8(data).rgb) * 0.5 + 0.5;
        }
        else if (!(voxIsTransparent(data) || data == 0))
        {
            vec3 bbox_min, bbox_max;

            bool do_bbox_isect = false;

            if (voxIsBottomSlab(data))
            {
                bbox_min = pos;
                bbox_max = pos + vec3(1.0, 0.5, 1.0);
                do_bbox_isect = true;
            }

            if (voxIsTopSlab(data))
            {
                bbox_min = pos + vec3(0.0, 0.5, 0.0);
                bbox_max = pos + vec3(1.0, 1.0, 1.0);
                do_bbox_isect = true;
            }

            if (voxIsSphere(data))
            {
                bbox_min = pos + vec3(0.3);
                bbox_max = pos + vec3(0.7);
                do_bbox_isect = true;
            }

            if (voxIsSheet(data))
            {
                bbox_min = pos;
                bbox_max = pos + vec3(1.0, 0.1, 1.0);
                do_bbox_isect = true;
            }

            if (voxIsColumn(data))
            {
                bbox_min = pos + vec3(0.4, 0.0, 0.4);
                bbox_max = pos + vec3(0.6, 1.0, 0.6);
                do_bbox_isect = true;
            }

            if (do_bbox_isect)
            {
                if (intersect_bbox(rayPos, ri, bbox_min, bbox_max, t)) res = 1.0;
            }
            else
            {
                intersect_bbox(rayPos, ri, pos, pos + vec3(1.0), t);
                res = 1.0;
            }
        }

        if (res > 0.0) break;
    
		mm = step(dis.xyz, dis.yzx) * step(dis.xyz, dis.zxy);
		dis += mm * rs * ri;
        pos += mm * rs;
	}

    if (res <= 0.0) return false;
	
    t = t * res;

	hitNormal = mm;
	hitPos = rayPos + t * rayDir - mod(cameraPosition, 1.0);

    if (dot(hitNormal, rayDir) > 0.0) hitNormal = -hitNormal; // Always keep the normal facing away from the ray direction.

	return true;
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