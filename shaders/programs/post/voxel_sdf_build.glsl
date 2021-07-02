#include "/libs/compat.glsl"
#include "/libs/voxelize.glslinc"

layout (local_size_x = 16, local_size_y = 16) in;

const ivec3 workGroups = ivec3(128, 64, 1);

uniform usampler2D shadowcolor0;

layout (r32ui) uniform uimage2D INPUT;
layout (r32ui) uniform uimage2D OUTPUT;

uint getVox(ivec3 vox_pos, ivec2 offset)
{
    ivec2 iuv = volume2planar(vox_pos);

#ifdef INITIAL
    if (iuv == ivec2(-1)) return 0;
#else
    if (iuv == ivec2(-1)) return 0x7FFFFFFF;
#endif

    return imageLoad(INPUT, iuv + offset).r;
}

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    ivec3 voxel_pos = planar2volume(iuv);

#ifdef INITIAL
    ivec2 offset = ivec2(0, 0);

    uint vox_center = imageLoad(INPUT, iuv).r;
    uint result = vox_center > 0 ? 0 : 0x7FFFFFFF;
#else
    ivec2 offset = ivec2(0, 1024);

    uint result = imageLoad(INPUT, iuv + offset).r;
#endif

    int stride = STRIDE;

#ifndef ONE_STEP
    for (int i = 0; i < 2; i++)
#endif
    {
        uint vox_top = getVox(voxel_pos + ivec3(0, stride, 0), offset);
        uint vox_bottom = getVox(voxel_pos + ivec3(0, -stride, 0), offset);
        uint vox_side0 = getVox(voxel_pos + ivec3(stride, 0, 0), offset);
        uint vox_side1 = getVox(voxel_pos + ivec3(-stride, 0, 0), offset);
        uint vox_side2 = getVox(voxel_pos + ivec3(0, 0, stride), offset);
        uint vox_side3 = getVox(voxel_pos + ivec3(0, 0, -stride), offset);

    #ifdef INITIAL
        vox_top = vox_top > 0 ? 0 : 0x7FFFFFFF;
        vox_bottom = vox_bottom > 0 ? 0 : 0x7FFFFFFF;
        vox_side0 = vox_side0 > 0 ? 0 : 0x7FFFFFFF;
        vox_side1 = vox_side1 > 0 ? 0 : 0x7FFFFFFF;
        vox_side2 = vox_side2 > 0 ? 0 : 0x7FFFFFFF;
        vox_side3 = vox_side3 > 0 ? 0 : 0x7FFFFFFF;
    #endif

        result = min(result, vox_top + stride);
        result = min(result, vox_bottom + stride);
        result = min(result, vox_side0 + stride);
        result = min(result, vox_side1 + stride);
        result = min(result, vox_side2 + stride);
        result = min(result, vox_side3 + stride);

        stride += STRIDE;
    }

    #ifdef FINAL
    uint prev = imageLoad(OUTPUT, iuv).r;
    uint new_enc = packUint6Unorm3x6(result, unpackUnorm4x8(prev).rgb) | (prev & 0xFF000000);
    imageStore(OUTPUT, iuv, uvec4(new_enc, 0, 0, 0)).r;
    #else
    imageStore(OUTPUT, ivec2(iuv.x, iuv.y + 1024), uvec4(result, 0, 0, 0));
    #endif

}