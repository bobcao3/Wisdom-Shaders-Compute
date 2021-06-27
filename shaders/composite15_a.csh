#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 256, local_size_y = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

layout (r32ui) uniform uimage2D shadowcolorimg0;

shared float16_t pdf[256];
shared float16_t cdf[256];

#include "/libs/color.glslinc"

// #define HISTOGRAM_NORMALIZATION

#define HISTOGRAM_MEDIAN

void main()
{
    pdf[gl_LocalInvocationIndex] = float16_t(imageLoad(shadowcolorimg0, ivec2(gl_LocalInvocationIndex, 0)).r);

    barrier();
    memoryBarrierShared();

    if (gl_LocalInvocationIndex == 0)
    {
        float16_t sum = 0.0;
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
            cdf[i] = 0.5 * (cdf[i] / sum + float16_t(i + 1) / 256.0);
#endif
        }        
    }

    barrier();
    memoryBarrierShared();

    uint encoded = floatBitsToUint(float(cdf[gl_LocalInvocationIndex]));

    imageStore(shadowcolorimg0, ivec2(gl_LocalInvocationIndex, 1), uvec4(encoded));
}