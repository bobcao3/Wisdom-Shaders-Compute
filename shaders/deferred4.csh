#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

#define RAY_GUIDING
// #define INCLUDE_IBL

#define DIFFUSE_ONLY

#include "/programs/post/rt_lighting.glsl"