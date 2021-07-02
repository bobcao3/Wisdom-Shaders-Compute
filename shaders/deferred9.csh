#version 450 compatibility

#define STRIDE 4

#define IN_OFFSET ivec2(0)
#define OUT_OFFSET ivec2(0, viewHeight * 0.5)

#include "/programs/post/sspt_spatial.comp"