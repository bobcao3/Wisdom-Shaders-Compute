#version 450 compatibility

#include "/libs/compat.glsl"

uniform sampler2D colortex10;
#define SOURCE(uv) texelFetch(colortex10, uv, 0).a

#include "/programs/post/sharpen_bilateral.glsl"