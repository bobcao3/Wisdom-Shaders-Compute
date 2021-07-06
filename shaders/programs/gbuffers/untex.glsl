#include "/libs/compat.glsl"

VERTEX_INOUT VertexOut {
    vec4 color;
    vec3 world_pos;
};

#ifdef FRAGMENT

#include "/libs/color.glslinc"

/* RENDERTARGETS: 6,7,8 */

void main()
{
    vec3 normal = normalize(cross(dFdx(world_pos), dFdy(world_pos)));

    gl_FragData[0] = vec4(fromGamma(color.rgb), color.a); // Albedo
#ifdef EMISSIVE
    gl_FragData[1] = vec4(normal, -1.0); // Depth, Flag, Normal
#else
    gl_FragData[1] = vec4(normal, 1.0); // Depth, Flag, Normal
#endif
    gl_FragData[2] = vec4(0.0); // F0, Smoothness
}

#endif

#ifdef VERTEX

#include "/libs/encode.glsl"

uniform vec2 taaOffset;

uniform mat4 gbufferModelViewInverse;

void main()
{
    vec4 view_pos = gl_ModelViewMatrix * gl_Vertex;
    world_pos = (gbufferModelViewInverse * view_pos).xyz;

    gl_Position = gl_ProjectionMatrix * view_pos;
    
    color = gl_Color;

    gl_Position.st += taaOffset * gl_Position.w;
}

#endif