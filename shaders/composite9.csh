#version 450 compatibility

#include "/libs/compat.glsl"

#define SOURCE(uv) texelFetch(colortex10, uv, 0).a

#include "/programs/post/sharpen_bilateral.glsl"