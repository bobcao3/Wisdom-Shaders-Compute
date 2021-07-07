#version 450 compatibility

#include "/libs/compat.glsl"

/* RENDERTARGETS: 13 */

uniform sampler2D colortex5;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    gl_FragData[0] = texelFetch(colortex5, iuv, 0);
}