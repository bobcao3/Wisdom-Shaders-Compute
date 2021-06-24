#version 450 compatibility

#define STRIDE 1

#define SVGF

#ifdef SVGF
#include "/programs/post/specular_spatial.comp"
#endif