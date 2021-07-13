#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

#define SPECULAR_PT
// #define FULL_RES
#define SSR_FIRST
#define SPLIT_SUM

#ifdef SPECULAR_PT
#endif

#define SPECULAR_ONLY

#include "/programs/post/rt_lighting.glsl"
