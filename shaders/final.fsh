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
const int colortex10Format = RGBA32F; // Color temporal (R11F_G11F_B10F for gameplay)
const int colortex11Format = RGBA16F; // Color temporal
const int colortex12Format = R11F_G11F_B10F; // SSPT temporal

const int shadowcolor0Format = R32UI;
const int shadowcolor1Format = RG32F;

const bool colortex3Clear = false;
const bool colortex9Clear = false;
const bool colortex10Clear = false;
const bool colortex12Clear = false;

const vec4 shadowcolor0ClearColor = vec4(0.0);

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

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 color = texelFetch(colortex2, iuv, 0).rgb;
 
    // color = texelFetch(colortex11, iuv, 0).rgb;

    // color = luma(color) * pow(color / luma(color), vec3(1.2));

    color = ACESFitted(toGamma(color)) * 1.1;

#ifdef APPLY_LUT
    color = applyLUT(color);
#endif

    // if (iuv.x < 2048 && iuv.y < 2048)
    //     color = vec3(texelFetch(shadowcolor1, iuv, 0).rgb);

    gl_FragColor = vec4(color, 1.0);
}