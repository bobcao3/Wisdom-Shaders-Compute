#version 450 compatibility

#define STRIDE 1
#define ONE_STEP

#define INPUT shadowcolorimg1
#define OUTPUT shadowcolorimg0

#include "/programs/post/voxel_sdf_build.glsl"