#include "/libs/compat.glsl"
#include "/settings.glsl"

VERTEX_INOUT VertexOut {
    vec4 color;
    vec2 uv;
    // flat vec2 normal_enc;
    vec3 normal;
    float view_z;
    vec2 lmcoord;
    flat int blockId;
};

#ifdef FRAGMENT

uniform sampler2D tex;

/* RENDERTARGETS: 6,7,8 */

#include "/libs/color.glslinc"

void main()
{
    vec4 albedo = texture(tex, uv) * color;
    
    albedo.rgb = fromGamma(albedo.rgb);

    gl_FragData[0] = albedo; // Albedo
    gl_FragData[1] = vec4(normal, (blockId == 29 || blockId == 30) ? 1.0 : 0.0); // Depth, Flag, Normal
    gl_FragData[2] = vec4(lmcoord, 0.0, 0.0); // F0, Smoothness
}

#endif

#ifdef VERTEX

#include "/libs/encode.glsl"

uniform vec2 taaOffset;

attribute vec2 mc_Entity;

void main()
{
    vec4 view_pos = gl_ModelViewMatrix * gl_Vertex;
    view_z = view_pos.z;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;
    // normal_enc = normalEncode(normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz));
    normal = normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz);

    uv = gl_MultiTexCoord0.st;

    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    blockId = int(mc_Entity.x);

    gl_Position.st += taaOffset * gl_Position.w;
}

#endif