#version 450 compatibility

/*

const int colortex0Format = R16F; // AO
const int colortex1Format = RG16F; // Motion vector
const int colortex2Format = R11F_G11F_B10F; // Composite
const int colortex3Format = R11F_G11F_B10F; // Skybox
const int colortex4Format = R32F; // Depth chain

const int colortex6Format = RGBA8; // Albedo
const int colortex7Format = RGB8_SNORM; // Normals
const int colortex8Format = RGBA8; // Specular

const int colortex9Format = R16F; // AO temporal
const int colortex10Format = R11F_G11F_B10F; // Color temporal

const bool colortex3Clear = false;
const bool colortex9Clear = false;
const bool colortex10Clear = false;

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

uniform sampler2D shadowtex0;

uniform vec2 invWidthHeight;

#include "/libs/color.glslinc"
#include "/libs/transform.glsl"

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 color = texelFetch(colortex2, iuv, 0).rgb;
 
    // vec4 color = vec4(linearizeDepth(texelFetch(colortex4, iuv, 0).r));

    // color = vec3(sampleLODmanual(colortex3, vec2(iuv) * invWidthHeight, 5).rgb);

    color = ACESFitted(toGamma(color)) * 1.1;

    // color = texelFetch(shadowtex0, iuv, 0).rrr;

    gl_FragColor = vec4(color, 1.0);
}