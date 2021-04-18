#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

#define GROUP 0

#include "/programs/post/deferred_lighting.glsl"