#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

// Full res lighting

#define LINEAR_ATMOS
#define GROUP 1

#include "/programs/post/deferred_lighting.glsl"