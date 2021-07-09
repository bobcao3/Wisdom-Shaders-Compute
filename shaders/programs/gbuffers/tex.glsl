#include "/libs/compat.glsl"
#include "/libs/noise.glsl"

VERTEX_INOUT VertexOut {
    vec2 uv;
    flat vec2 bound_uv;
    vec2 lmcoord;
    flat uint normal_enc;
    flat uint tangent_enc;
    flat float flag;
    flat vec2 miduv;
    lowp vec4 color;
};

#ifdef FRAGMENT

uniform sampler2D tex;
uniform sampler2D specular;
uniform sampler2D normals;

/* RENDERTARGETS: 6,7 */

layout (location = 0) out uvec2 albedo_specular;
layout (location = 1) out vec4 normal_flag;

#include "/libs/color.glslinc"


#define USE_AF

void main()
{
    vec2 atlas_size = textureSize(tex, 0);

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    float dL = min(length(ddx * atlas_size), length(ddy * atlas_size));
    float lod = clamp(round(log2(dL) - 1.0), 0, 3);
    
    #define AF_TAPS 4 // [2 4 8 16]

#ifdef USE_AF
    vec4 albedo = vec4(0.0, 0.0, 0.0, textureLod(tex, uv, lod).a);
    
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
    vec4 albedo = texture(tex, uv);
#endif

    albedo.rgb *= color.rgb;

    if (albedo.a < 0.99)
    {
        if (texelFetch(noisetex, ivec2(gl_FragCoord.st) & 0xFF, 0).r > albedo.a) discard;
    }

    vec4 spec = texture(specular, uv);

#ifndef MC_TEXTURE_FORMAT_LAB_PBR
    spec.g *= (229.0 / 255.0);
    spec.r = (spec.r);
#endif

    f16vec3 normal = f16vec3(unpackSnorm4x8(normal_enc).rgb);
    f16vec3 tangent = f16vec3(unpackSnorm4x8(tangent_enc).rgb);

    f16vec3 bitangent = normalize(cross(tangent, normal));
    mat3 tbn = mat3(tangent, bitangent, normal);

    f16vec3 normal_tex = f16vec3(texture(normals, uv).rgb);
    
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    normal_tex.rg = normal_tex.rg * f16(2.0) - f16(1.0);
    f16vec3 normal_sampled = normalize(f16vec3(normal_tex.rg, sqrt(max(f16(0.0), f16(1.0) - dot(normal_tex.xy, normal_tex.xy)))));
#else
    f16vec3 normal_sampled = normal_tex.rgb * f16(2.0) - f16(1.0);
#endif

    normal_sampled = f16vec3(normalize(tbn * vec3(normal_sampled) + normal * 0.3));

    albedo_specular = uvec2(packUnorm4x8(albedo), packUnorm4x8(vec4(lmcoord, spec.rg)));
    normal_flag = vec4(normal_sampled, flag); // Depth, Flag, Normal
}

#endif

#ifdef VERTEX

#include "/libs/encode.glsl"

uniform vec2 taaOffset;

attribute vec2 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;

void main()
{
    vec4 view_pos = gl_ModelViewMatrix * gl_Vertex;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;
    f16vec3 normal = f16vec3(mat3(gbufferModelViewInverse) * normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz));

    f16vec3 tangent_adj = f16vec3(at_tangent.w == 0.0 ? -at_tangent.xyz : at_tangent.xyz);
    f16vec3 tangent = f16vec3(mat3(gbufferModelViewInverse) * normalize(mat3(gl_NormalMatrix) * tangent_adj));

    normal_enc = packSnorm4x8(vec4(normal, 0.0));
    tangent_enc = packSnorm4x8(vec4(tangent, 0.0));

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