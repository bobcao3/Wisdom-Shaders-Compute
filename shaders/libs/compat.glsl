#ifndef _INCLUDE_COMPAT
#define _INCLUDE_COMPAT

#ifdef VERTEX
#define inout out
#else
#define inout in
#endif

#define USE_HALF

#if (defined(USE_HALF) && defined(MC_GL_EXT_shader_explicit_arithmetic_types))

#extension GL_EXT_shader_explicit_arithmetic_types : enable
#define SUPPORT_HALF

#elif (defined(USE_HALF) && defined(MC_GL_NV_gpu_shader5))

#extension GL_NV_gpu_shader5 : enable
#define SUPPORT_HALF

#elif (defined(USE_HALF) && defined(MC_GL_AMD_gpu_shader_half_float))

#extension GL_AMD_gpu_shader_half_float : enable
#define SUPPORT_HALF

#define int8_t int
#define int16_t int
#define int32_t int

#else

#define float32_t float
#define f32vec2 vec2
#define f32vec3 vec3
#define f32vec4 vec4
#define float16_t float
#define f16vec2 vec2
#define f16vec3 vec3
#define f16vec4 vec4
#define int8_t int
#define int16_t int
#define int32_t int

#endif

float L1dist(vec2 v)
{
    return max(abs(v.x), abs(v.y));
}

float L2dist2(vec2 v)
{
    return dot(v, v);
}

float pow1d5(float c)
{
	return c * sqrt(c);
}

vec2 pow1d5(vec2 c)
{
	return c * sqrt(c);
}

vec3 pow1d5(vec3 c)
{
	return c * sqrt(c);
}

vec4 pow1d5(vec4 c)
{
	return c * sqrt(c);
}

float pow2(float c)
{
	return c * c;
}

vec2 pow2(vec2 c)
{
	return c * c;
}

vec3 pow2(vec3 c)
{
	return c * c;
}

vec4 pow2(vec4 c)
{
	return c * c;
}

float pow3(float c)
{
    return c * c * c;
}

vec2 pow3(vec2 c)
{
    return c * c * c;
}

vec3 pow3(vec3 c)
{
    return c * c * c;
}

vec4 pow3(vec4 c)
{
    return c * c * c;
}

float pow4(float c)
{
    return (c * c) * (c * c);
}

vec2 pow4(vec2 c)
{
    return (c * c) * (c * c);
}

vec3 pow4(vec3 c)
{
    return (c * c) * (c * c);
}

vec4 pow4(vec4 c)
{
    return (c * c) * (c * c);
}

float pow5(float c)
{
    return (c * c) * (c * c) * c;
}

vec2 pow5(vec2 c)
{
    return (c * c) * (c * c) * c;
}

vec3 pow5(vec3 c)
{
    return (c * c) * (c * c) * c;
}

vec4 pow5(vec4 c)
{
    return (c * c) * (c * c) * c;
}

float pow6(float c)
{
    return (c * c) * (c * c) * (c * c);
}

vec2 pow6(vec2 c)
{
    return (c * c) * (c * c) * (c * c);
}

vec3 pow6(vec3 c)
{
    return (c * c) * (c * c) * (c * c);
}

vec4 pow6(vec4 c)
{
    return (c * c) * (c * c) * (c * c);
}

float pow7(float c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

vec2 pow7(vec2 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

vec3 pow7(vec3 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

vec4 pow7(vec4 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

float pow8(float c)
{
    float t = (c * c) * (c * c);
    return t * t;
}

vec2 pow8(vec2 c)
{
    vec2 t = (c * c) * (c * c);
    return t * t;
}

vec3 pow8(vec3 c)
{
    vec3 t = (c * c) * (c * c);
    return t * t;
}

vec4 pow8(vec4 c)
{
    vec4 t = (c * c) * (c * c);
    return t * t;
}

uint packUint6Unorm3x6(uint v, vec3 c)
{
    const vec3 mult = vec3((1 << 6) - 1, (1 << 6) - 1, (1 << 6) - 1);
    uvec3 enc = uvec3(clamp(c, vec3(0.0), vec3(1.0)) * mult);
    v = min(v, (1 << 6) - 1);
    return (v << 18) | (enc.r << 12) | (enc.g << 6) | (enc.b);
}

vec3 unpackUint6Unorm3x6(uint e, out uint v)
{
    v = (e >> 18) & 0x3F;
    const vec3 mult = 1.0 / vec3((1 << 6) - 1, (1 << 6) - 1, (1 << 6) - 1);
    uvec3 enc = uvec3((e >> 12) & 0x3F, (e >> 6) & 0x3F, (e) & 0x3F);
    return vec3(enc) * mult;
}

#ifdef SUPPORT_HALF
float16_t L1dist(f16vec2 v)
{
    return max(abs(v.x), abs(v.y));
}

float16_t L2dist2(f16vec2 v)
{
    return dot(v, v);
}

float16_t pow1d5(float16_t c)
{
	return c * sqrt(c);
}

f16vec2 pow1d5(f16vec2 c)
{
	return c * sqrt(c);
}

f16vec3 pow1d5(f16vec3 c)
{
	return c * sqrt(c);
}

f16vec4 pow1d5(f16vec4 c)
{
	return c * sqrt(c);
}

float16_t pow2(float16_t c)
{
	return c * c;
}

f16vec2 pow2(f16vec2 c)
{
	return c * c;
}

f16vec3 pow2(f16vec3 c)
{
	return c * c;
}

f16vec4 pow2(f16vec4 c)
{
	return c * c;
}

float16_t pow3(float16_t c)
{
    return c * c * c;
}

f16vec2 pow3(f16vec2 c)
{
    return c * c * c;
}

f16vec3 pow3(f16vec3 c)
{
    return c * c * c;
}

f16vec4 pow3(f16vec4 c)
{
    return c * c * c;
}

float16_t pow4(float16_t c)
{
    return (c * c) * (c * c);
}

f16vec2 pow4(f16vec2 c)
{
    return (c * c) * (c * c);
}

f16vec3 pow4(f16vec3 c)
{
    return (c * c) * (c * c);
}

f16vec4 pow4(f16vec4 c)
{
    return (c * c) * (c * c);
}

float16_t pow5(float16_t c)
{
    return (c * c) * (c * c) * c;
}

f16vec2 pow5(f16vec2 c)
{
    return (c * c) * (c * c) * c;
}

f16vec3 pow5(f16vec3 c)
{
    return (c * c) * (c * c) * c;
}

f16vec4 pow5(f16vec4 c)
{
    return (c * c) * (c * c) * c;
}

float16_t pow6(float16_t c)
{
    return (c * c) * (c * c) * (c * c);
}

f16vec2 pow6(f16vec2 c)
{
    return (c * c) * (c * c) * (c * c);
}

f16vec3 pow6(f16vec3 c)
{
    return (c * c) * (c * c) * (c * c);
}

f16vec4 pow6(f16vec4 c)
{
    return (c * c) * (c * c) * (c * c);
}

float16_t pow7(float16_t c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

f16vec2 pow7(f16vec2 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

f16vec3 pow7(f16vec3 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

f16vec4 pow7(f16vec4 c)
{
    return (c * c) * (c * c) * (c * c) * c;
}

float16_t pow8(float16_t c)
{
    float16_t t = (c * c) * (c * c);
    return t * t;
}

f16vec2 pow8(f16vec2 c)
{
    f16vec2 t = (c * c) * (c * c);
    return t * t;
}

f16vec3 pow8(f16vec3 c)
{
    f16vec3 t = (c * c) * (c * c);
    return t * t;
}

f16vec4 pow8(f16vec4 c)
{
    f16vec4 t = (c * c) * (c * c);
    return t * t;
}
#endif

#endif
