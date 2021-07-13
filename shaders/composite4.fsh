#version 450 compatibility

#include "/libs/compat.glsl"

/* RENDERTARGETS: 13 */

uniform sampler2D colortex5;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex5, iuv, 0);

    gl_FragData[0] = color;
}