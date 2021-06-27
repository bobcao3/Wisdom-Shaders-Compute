#version 450 compatibility

#include "/libs/compat.glsl"

#define SPECULAR_PT
#define SPLIT_SUM

#ifdef SPECULAR_PT
#endif

#define SPECULAR_ONLY

#include "/programs/post/rt_lighting.glsl"
