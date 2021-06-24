#version 450 compatibility

#include "/libs/compat.glsl"

#define RAY_GUIDING
#define INCLUDE_IBL
#define DIFFUSE_ONLY

#include "/programs/post/rt_lighting.glsl"