#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

layout (r32f) uniform image2D colorimg4;
layout (r32ui) uniform uimage2D shadowcolorimg0;

uniform sampler2D colortex2;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

shared float16_t luminance[256];

uniform float viewWidth;
uniform float viewHeight;

#include "/libs/color.glslinc"

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    f16vec3 color = f16vec3(texelFetch(colortex2, iuv, 0).rgb);

    float16_t L = max(max(color.r, color.g), color.b);

    luminance[gl_LocalInvocationIndex] = L;

    if (gl_WorkGroupID.x == 0 && gl_WorkGroupID.y == 0) imageStore(shadowcolorimg0, ivec2(gl_LocalInvocationIndex, 0), uvec4(0));

    for (int i = 1; i <= 8; i++)
    {
        barrier();
        memoryBarrierShared();

        int stride = 1 << i;

        if (((gl_LocalInvocationIndex >> i) & 0x1) == 1) return;

        luminance[gl_LocalInvocationIndex] += luminance[gl_LocalInvocationIndex + (stride >> 1)];
    }

    imageStore(colorimg4, iuv, vec4(luminance[0] / float16_t(256.0), 0, 0, 1));
}