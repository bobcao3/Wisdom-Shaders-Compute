#ifndef _INCLUDE_TRANSFORM
#define _INCLUDE_TRANSFORM

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform float viewWidth;
uniform float viewHeight;

uniform float near, far;

#include "/configs.glsl"

float norm2(in vec3 a, in vec3 b) {
    a -= b;
    return dot(a, a);
}

float square(float a) {
    return a * a;
}

#ifdef USE_HALF
float16_t square16(float16_t a) {
    return a * a;
}
#endif

float fsqrt(float x) {
    // [Drobot2014a] Low Level Optimizations for GCN
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1));
}

float facos(float x) {
    // [Eberly2014] GPGPU Programming for Games and Science
    float res = -0.156583 * abs(x) + 3.1415926 / 2.0;
    res *= fsqrt(1.0 - abs(x));
    return x >= 0 ? res : 3.1415926 - res;
}


#define PI 3.1415926f

vec3 project_uv2skybox(vec2 uv) {
    vec2 rad = uv * 8.0 * PI;
    rad.y -= PI * 0.5;
    float cos_y = cos(rad.y);
    return vec3(cos(rad.x) * cos_y, sin(rad.y), sin(rad.x) * cos_y);
}

vec2 project_skybox2uv(vec3 nwpos) {
    vec2 rad = vec2(atan(nwpos.z, nwpos.x), asin(nwpos.y));
    rad += vec2(step(0.0, -rad.x) * (PI * 2.0), PI * 0.5);
    rad *= 0.125 / PI;
    return rad;
}

vec3 sampleLODmanual(sampler2D s, vec2 uv, int lod)
{
    float h_offset = (1.0 - pow(0.5, float(lod)));
    return texture(s, uv * pow(0.5, float(lod)) + vec2(h_offset, 0.0)).rgb;
}

uniform sampler2D depthtex0;

float getDepth(in ivec2 iuv) {
    return texelFetch(depthtex0, iuv, 0).r;
}

float linearizeDepth(in float d) {
    return (2 * near) / (far + near - (d * 2.0 - 1.0) * (far - near));
}

vec4 linearizeDepth(in vec4 d) {
    return (2 * near) / (far + near - (d * 2.0 - 1.0) * (far - near));
}

vec3 getProjPos(in ivec2 iuv) {
    return vec3(vec2(iuv) * invWidthHeight, getDepth(iuv)) * 2.0 - 1.0;
}

vec3 getProjPos(in ivec2 iuv, in float depth) {
    return vec3(vec2(iuv) * invWidthHeight, depth) * 2.0 - 1.0;
}

vec3 getProjPos(in vec2 uv, in float depth) {
    return vec3(uv, depth) * 2.0 - 1.0;
}

vec3 proj2view(in vec3 proj_pos) {
    vec4 view_pos = gbufferProjectionInverse * vec4(proj_pos, 1.0);
    return view_pos.xyz / view_pos.w;
}

vec3 view2proj(in vec3 view_pos) {
    vec4 proj_pos = gbufferProjection * vec4(view_pos, 1.0);
    return proj_pos.xyz / proj_pos.w;
}

vec3 view2world(in vec3 view_pos) {
    return (gbufferModelViewInverse * vec4(view_pos.xyz, 1.0)).xyz;
}

vec3 world2view(in vec3 wpos) {
    return (gbufferModelView * vec4(wpos, 1.0)).xyz;
}

vec3 world2shadowView(in vec3 world_pos) {
    return (shadowModelView * vec4(world_pos, 1.0)).xyz;
}

mat4 shadowMVP = shadowProjection * shadowModelView;

vec3 world2shadowProj(in vec3 world_pos) {
    vec4 shadow_proj_pos = vec4(world_pos, 1.0);
    shadow_proj_pos = shadowMVP * shadow_proj_pos;
    shadow_proj_pos.xyz /= shadow_proj_pos.w;
    vec3 spos = shadow_proj_pos.xyz;

    spos.xy /= length(spos.xy) * 0.85 + 0.15;
    spos.z *= 0.5;

    return spos;
}

#endif