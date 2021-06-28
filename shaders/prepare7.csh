#version 450 compatibility

#define STRIDE 4

#define INPUT shadowcolorimg0
#define OUTPUT shadowcolorimg1

#include "/programs/post/voxel_sdf_build.glsl"