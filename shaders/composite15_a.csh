#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 256, local_size_y = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

layout (r32ui) uniform uimage2D shadowcolorimg0;
layout (r11f_g11f_b10f) uniform image2D colorimg3;

uniform float viewWidth;
uniform float viewHeight;

shared f16 pdf[256];
shared f16 cdf[256];

#include "/libs/color.glslinc"

// #define HISTOGRAM_NORMALIZATION

#define HISTOGRAM_MEDIAN

uniform float frameTime;

void main()
{
    f16 history = f16(imageLoad(colorimg3, ivec2(viewWidth - 256 + gl_LocalInvocationIndex, viewHeight - 1)).r);
    f16 new = mix(history, f16(imageLoad(shadowcolorimg0, ivec2(gl_LocalInvocationIndex, 0)).r), f16(frameTime));

    pdf[gl_LocalInvocationIndex] = new;

    imageStore(colorimg3, ivec2(viewWidth - 256 + gl_LocalInvocationIndex, viewHeight - 1), vec4(new, 0.0, 0.0, 0.0));

    barrier();
    memoryBarrierShared();

    if (gl_LocalInvocationIndex == 0)
    {
        f16 sum = 0.0;
        for (int i = 0; i < 256; i++)
        {
            sum += pdf[i];
            cdf[i] = sum;
        }

        for (int i = 0; i < 256; i++)
        {
#ifdef HISTOGRAM_MEDIAN
            cdf[i] = cdf[i] / sum;
#else
            cdf[i] = 0.5 * (cdf[i] / sum + f16(i + 1) / 256.0);
#endif
        }        
    }

    barrier();
    memoryBarrierShared();

    uint encoded = floatBitsToUint(float(cdf[gl_LocalInvocationIndex]));
    imageStore(shadowcolorimg0, ivec2(gl_LocalInvocationIndex, 1), uvec4(encoded));
}