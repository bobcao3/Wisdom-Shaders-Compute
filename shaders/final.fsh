#version 450 compatibility

/*

const int colortex0Format = R16F; // AO
const int colortex1Format = RG16F; // Motion vector
const int colortex4Format = R32F; // Depth chain

const int colortex6Format = RGBA8; // Albedo
const int colortex7Format = RG16; // Normals
const int colortex8Format = RGBA8; // Specular

const int colortex9Format = R16F; // AO temporal

const bool colortex6MipmapEnabled = true;
const bool colortex7MipmapEnabled = true;
const bool colortex8MipmapEnabled = true;

*/

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

uniform vec2 invWidthHeight;

#include "/libs/color.glslinc"
#include "/libs/transform.glsl"

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex9, iuv / 2, 0).rrrr;
    // vec4 color = vec4(linearizeDepth(texelFetch(colortex4, iuv, 0).r));

    // vec4 color = vec4(texelFetch(colortex1, iuv, 0).rg, 0.0, 1.0);

    color = toGamma(color);

    gl_FragColor = color;
}