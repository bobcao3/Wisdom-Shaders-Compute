#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

layout (r16f) uniform image2D colorimg4;
layout (r32ui) uniform uimage2D shadowcolorimg0;

uniform sampler2D colortex4;

const vec2 workGroupsRender = vec2(0.063f, 0.063f);

uniform float viewWidth;
uniform float viewHeight;

#include "/libs/color.glslinc"

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * 16;

    if (iuv.x >= viewWidth || iuv.y >= viewHeight) return;

    float L = texelFetch(colortex4, iuv, 0).r;

    int bin = clamp(int(log(L) * histogram_log_scale + histogram_log_zero), 0, 255);

    imageAtomicAdd(shadowcolorimg0, ivec2(bin, 0), 1);
}