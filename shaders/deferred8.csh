#version 450 compatibility

#define STRIDE 2

#define IN_OFFSET ivec2(0, viewHeight * 0.5)
#define OUT_OFFSET ivec2(0)

#include "/programs/post/sspt_spatial.comp"