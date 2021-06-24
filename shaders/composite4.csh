#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex2;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

layout (r11f_g11f_b10f) uniform image2D colorimg2;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"

#include "/configs.glsl"

uniform sampler2D depthtex1;

uniform vec3 sunPosition;

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    float depth = getDepth(iuv);

    if (depth < 1.0)
    {
        vec3 color = texelFetch(colortex2, iuv, 0).rgb;

        if (texelFetch(colortex7, iuv, 0).a >= 0.0)
        {
            color += texelFetch(colortex5, iuv / 2, 0).rgb;
        }

        imageStore(colorimg2, iuv, vec4(color, 1.0));
    }
}