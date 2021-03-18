#ifndef _INCLUDE_CONFIGS
#define _INCLUDE_CONFIGS

const float sunPathRotation = -50.0;
const int shadowMapResolution = 2048; // [512 768 1024 1512 2048 3200 4096]
const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);
const float shadowDistance = 120.0; // [64.0 90.0 120.0 160.0 200.0 400.0 800.0 1600.0]
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 1.0;

const int shadowMapQuadRes = shadowMapResolution / 2;

const float ambientOcclusionLevel = 0.0f;

#endif