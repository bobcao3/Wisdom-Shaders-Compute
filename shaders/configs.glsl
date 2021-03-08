#ifndef _INCLUDE_CONFIGS
#define _INCLUDE_CONFIGS

const float sunPathRotation = -40.0;
const int shadowMapResolution = 2048; // [512 768 1024 1512 2048 3200 4096]
const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);
const float shadowDistance = 12.0; // [4.0 6.0 8.0 10.0 12.0 16.0 24.0 32.0 48.0 64.0]
const float shadowDistanceRenderMul = 16.0;
const float shadowIntervalSize = 1.0;

const int shadowMapQuadRes = shadowMapResolution / 2;

const float ambientOcclusionLevel = 0.0f;

const float CSMLevel0 = 2.0f;
const float CSMLevel1 = 5.0f;
const float CSMLevel2 = 12.0f;
const float CSMLevel3 = 32.0f;

const float invCSMLevel0 = 1.0 / CSMLevel0;
const float invCSMLevel1 = 1.0 / CSMLevel1;
const float invCSMLevel2 = 1.0 / CSMLevel2;
const float invCSMLevel3 = 1.0 / CSMLevel3;

#endif