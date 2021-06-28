#include "/libs/compat.glsl"
#include "/libs/noise.glsl"

VERTEX_INOUT VertexOut {
    vec4 color;
    vec2 uv;
    // flat vec2 normal_enc;
    vec3 normal;
    vec3 tangent;
    float view_z;
    vec2 lmcoord;
    float flag;

    vec2 miduv;
    flat vec2 bound_uv;
};

#ifdef FRAGMENT

uniform sampler2D tex;
uniform sampler2D specular;
uniform sampler2D normals;

/* RENDERTARGETS: 6,7,8 */

#include "/libs/color.glslinc"


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

    if (albedo.a < 0.05)
    {
        gl_FragData[0] = vec4(0.0);
        return;
    }
    
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
    
    albedo.rgb = fromGamma(albedo.rgb);

    vec4 spec = texture(specular, uv);

#ifndef MC_TEXTURE_FORMAT_LAB_PBR
    spec.g *= (229.0 / 255.0);
    spec.r = sqrt(spec.r);
#endif

    vec3 bitangent = normalize(cross(tangent, normal));
    mat3 tbn = mat3(tangent, bitangent, normal);

    vec3 normal_tex = texture(normals, uv).rgb; normal_tex.rg = normal_tex.rg * 2.0 - 1.0;
    vec3 normal_sampled = vec3(normal_tex.rg, sqrt(1.0 - dot(normal_tex.xy, normal_tex.xy)));

    normal_sampled = normalize(mix(tbn * normal_sampled, normal, 0.5));

    gl_FragData[0] = albedo; // Albedo
    gl_FragData[1] = vec4(normal_sampled, flag); // Depth, Flag, Normal
    gl_FragData[2] = vec4(lmcoord, spec.rg);
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
    view_z = view_pos.z;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;
    // normal_enc = normalEncode(normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz));
    normal = mat3(gbufferModelViewInverse) * normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz);

    vec3 tangent_adj = at_tangent.w == 0.0 ? -at_tangent.xyz : at_tangent.xyz;
    tangent = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * tangent_adj);

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