#include "/libs/compat.glsl"
#include "/settings.glsl"

VERTEX_INOUT VertexOut {
    vec4 color;
    flat vec2 normal_enc;
    float view_z;
};

#ifdef FRAGMENT

#include "/libs/color.glslinc"

/* RENDERTARGETS: 6,7,8 */

void main()
{
    gl_FragData[0] = vec4(fromGamma(color.rgb), color.a); // Albedo
    gl_FragData[1] = vec4(0.0); // Depth, Flag, Normal
#ifdef SPECULAR
    gl_FragData[2] = vec4(0.0); // F0, Smoothness
#endif
}

#endif

#ifdef VERTEX

#include "/libs/encode.glsl"

void main()
{
    vec4 view_pos = gl_ModelViewMatrix * gl_Vertex;
    view_z = view_pos.z;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;
    normal_enc = normalEncode(normalize(mat3(gl_NormalMatrix) * gl_Normal.xyz));
}

#endif