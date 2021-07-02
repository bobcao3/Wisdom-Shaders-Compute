#version 450 compatibility

#define STRIDE 8

#define INPUT shadowcolorimg1
#define OUTPUT shadowcolorimg0

#define FINAL

#include "/programs/post/voxel_sdf_build.glsl"