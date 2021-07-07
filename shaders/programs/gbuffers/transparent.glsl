#include "/libs/compat.glsl"
#include "/libs/noise.glsl"

VERTEX_INOUT VertexOut {
    vec4 color;
    vec2 uv;
    // flat vec2 normal_enc;
    vec3 normal;
    vec2 lmcoord;
    float flag;

    vec2 miduv;
    flat vec2 bound_uv;

    vec4 view_pos;
};

#ifdef FRAGMENT

uniform vec2 invWidthHeight;

#include "/libs/transform.glsl"

uniform sampler2D tex;

/* RENDERTARGETS: 11,6,7 */

layout(location = 0) out vec4 transparent_albedo;
layout(location = 1) out uvec2 albedo_specular;
layout(location = 2) out vec4 normal_flag;

#include "/libs/color.glslinc"

uniform sampler2D colortex3;

#define USE_AF

void main()
{
    vec4 albedo = texture(tex, uv);

    vec2 atlas_size = textureSize(tex, 0);

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    float dL = min(length(ddx * atlas_size), length(ddy * atlas_size));
    float lod = clamp(round(log2(dL) - 1.0), 0, 3);
    
    #define AF_TAPS 8 // [2 4 8 16]

#ifdef USE_AF
    albedo.a = textureLod(tex, uv, lod).a;
    
    vec2 rect_size = abs(bound_uv - miduv);
    
    for (int i = 0; i < AF_TAPS; i++)
    {
        vec2 offset = WeylNth(i);

        vec2 offset_from_mid = uv + (offset - 0.5) * max(ddx, ddy) - miduv;
        vec2 uv_offset = miduv + clamp(offset_from_mid, -rect_size, rect_size);// * sign(offset_from_mid);

        albedo.rgb += textureLod(tex, uv_offset, lod).rgb;
    }

    albedo.rgb /= float(AF_TAPS);
#else
    albedo = texture(tex, uv);
#endif

    albedo *= color;

    if (albedo.a < 0.1)
    {
        albedo.rgb = vec3(1.0);
        albedo.a = 0.4;
    }

    transparent_albedo = albedo; // Albedo
    albedo_specular = uvec2(packUnorm4x8(albedo), packUnorm4x8(vec4(lmcoord, 1.0, 0.04)));
    normal_flag = vec4(normal, flag); // Depth, Flag, Normal
}

#endif

#ifdef VERTEX

#include "/libs/encode.glsl"

uniform vec2 taaOffset;

attribute vec2 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelViewInverse;

void main()
{
    view_pos = gl_ModelViewMatrix * gl_Vertex;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;
    // normal_enc = normalEncode(normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz));
    normal = mat3(gbufferModelViewInverse) * normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz);

    color.rgb = color.rgb * 0.6 + 0.4;

    if (mc_Entity.y == 1.0)
    {
        color.rgb = vec3(1.0);
    }

    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    miduv = mc_midTexCoord.st;
    bound_uv = uv;

    uint blockId = uint(mc_Entity.x) & 0xFF;

    if ((blockId & 0x1) > 0 || lmcoord.x > 0.965)
        flag = -1.0;
    else
        flag = 0.0;

    gl_Position.st += taaOffset * gl_Position.w;
}

#endif