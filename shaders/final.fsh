#version 450 compatibility

#include "/libs/compat.glsl"

/*

const int colortex0Format = R16F; // AO
const int colortex1Format = RG16F; // Motion vector
const int colortex2Format = R11F_G11F_B10F; // Composite
const int colortex3Format = R11F_G11F_B10F; // Skybox
const int colortex4Format = R32F; // Depth chain
const int colortex5Format = R11F_G11F_B10F; // Composite 2

const int colortex6Format = RGBA8; // Albedo
const int colortex7Format = RGBA8_SNORM; // Normals
const int colortex8Format = RGBA8; // Specular

const int colortex9Format = R16F; // AO temporal
const int colortex10Format = RGBA16F; // Color temporal (R11F_G11F_B10F for gameplay)
const int colortex11Format = RGBA16F; // Color temporal
const int colortex12Format = RGBA16F; // SSPT temporal
const int colortex13Format = RGBA16F; // SSPT temporal

const int shadowcolor0Format = R32UI;
const int shadowcolor1Format = RG32F;

const bool colortex3Clear = false;
const bool colortex9Clear = false;
const bool colortex10Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;

const vec4 shadowcolor0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 shadowcolor1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

*/

#include "/configs.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;

uniform sampler2D colortex15;

uniform sampler2D shadowtex1;
uniform usampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform vec2 invWidthHeight;

#include "/libs/color.glslinc"
#include "/libs/transform.glsl"
#include "/libs/noise.glsl"

vec3 applyLUT(vec3 c)
{
    c += bayer16(gl_FragCoord.st) * (1.0 / 64.0);

    c = clamp(c, vec3(0.03125), vec3(255.0 / 256.0));

    int blue0 = int(floor(c.b * 64.0));
    int blue1 = int(ceil(c.b * 64.0));

    vec2 offset0 = vec2(blue0 % 8, blue0 / 8) * 0.125;
    vec2 offset1 = vec2(blue1 % 8, blue1 / 8) * 0.125;

    vec2 uv0 = offset0 + c.rg * 0.125;
    vec2 uv1 = offset1 + c.rg * 0.125;

    vec3 lut0 = texture(colortex15, uv0).rgb;
    vec3 lut1 = texture(colortex15, uv0).rgb;

    return mix(lut0, lut1, fract(c.b * 64.0));
}

// #define APPLY_LUT

// #define HISTOGRAM_NORMALIZATION

#define HISTOGRAM_MEDIAN

in flat float median_luma;
in flat int median_index;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 color = texelFetch(colortex2, iuv, 0).rgb;

    float local_average_luma = exp2(texelFetch(colortex0, iuv, 0).r) * (1.0 / 500.0);
    float pixel_luma = luma(color);

    color = color / pixel_luma; // Normalize

#define SHARPEN_STRENGTH 0.3 // [0.1 0.2 0.3 0.4 0.5 0.6]

    float new_luma = clamp((pixel_luma - local_average_luma) * (1.0 + SHARPEN_STRENGTH) + local_average_luma, pixel_luma * 0.5, 1e5);

#ifdef HISTOGRAM_NORMALIZATION
    // Histogram normalization
    float Yin = clamp(log(new_luma) * histogram_log_scale + histogram_log_zero, 0.0, 255.0 - 1e-5);
    float Yin_lower = floor(Yin);
    float Yout_lower = uintBitsToFloat(texelFetch(shadowcolor0, ivec2(Yin_lower - 1, 1), 0).r);
    float Yout_upper = uintBitsToFloat(texelFetch(shadowcolor0, ivec2(Yin_lower, 1), 0).r);

    if (Yin_lower >= 255) Yout_upper = 1.0;
    if (Yin_lower == 0) Yout_lower = 0.0;

    float Yout = mix(Yout_lower, Yout_upper, Yin - Yin_lower);
    new_luma = mix(new_luma, exp((Yout * 256.0 - histogram_log_zero) / 32.0), 0.5);
#endif

#ifdef HISTOGRAM_MEDIAN
    new_luma = clamp(new_luma * (0.05 / median_luma), new_luma * 0.7, new_luma * 10.0);
#endif

#define SATURATION 0.4 // [-1.0 -0.8 -0.6 -0.4 -0.2 0.0 0.2 0.4 0.6 0.8 1.0]

    color = (new_luma) * pow(color, vec3(1.0 + SATURATION));

    color = ACESFitted(toGamma(color));
    // color = toHLG(reinhard(color, 1.0), 0.5);
    // color = toGamma(reinhard(color, 1.0));

#ifdef APPLY_LUT
    color = applyLUT(color);
#endif

    // if (iuv.x < viewWidth / 16 && iuv.y < viewHeight / 16)
    //     color = texelFetch(colortex4, iuv * 16, 0).rrr * histogram_log_scale;

    // if (iuv.x < 512 && iuv.y < 256)
    // {
    //     color = vec3(float( uintBitsToFloat(texelFetch(shadowcolor0, ivec2(iuv.x >> 2, 1), 0).r) * 512.0 < iuv.y));
    //     if ((iuv.x >> 2) == median_index) color = vec3(1.0, 0.0, 0.0);
    // }

    if (iuv.x < 512 && iuv.y < 256)
    {
        color = vec3(float(texelFetch(shadowcolor0, ivec2(iuv.x >> 1, 0), 0).r) < iuv.y * 2);
        if ((iuv.x >> 1) == median_index) color = vec3(1.0, 0.0, 0.0);
    }

    gl_FragColor = vec4(color, 1.0);
}