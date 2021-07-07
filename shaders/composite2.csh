#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

layout (r11f_g11f_b10f) uniform image2D colorimg5;

uniform vec2 invWidthHeight;

uniform sampler2D colortex1;
uniform sampler2D colortex13;

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) * 2;
    ivec2 iuv_orig = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    vec4 color = imageLoad(colorimg5, iuv_orig);

    vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;

    vec4 history = texture(colortex13, history_uv * 0.5);

    float weight = 0.1;

    if (history_uv.x < 0.0 || history_uv.x >= 1.0 || history_uv.y < 0.0 || history_uv.y >= 1.0) weight = 1.0;

    color = mix(history, color, weight);

    imageStore(colorimg5, iuv_orig, color);
}