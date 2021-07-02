#version 450 compatibility

#define STRIDE 1

#define SVGF

#define IN_OFFSET ivec2(0)
#define OUT_OFFSET ivec2(0, viewHeight * 0.5)

#ifdef SVGF
#include "/programs/post/sspt_spatial.comp"
#endif