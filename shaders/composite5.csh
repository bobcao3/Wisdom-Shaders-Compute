#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

layout (r11f_g11f_b10f) uniform image2D colorimg5;

uniform vec2 invWidthHeight;

uniform sampler2D colortex5;

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);
    
    vec3 color = texelFetch(colortex5, iuv, 0).rgb;

    vec3 min_neighbour = color;
    vec3 max_neighbour = color;
    
    vec3 sample00 = texelFetchOffset(colortex5, iuv, 0, ivec2(-1, -1)).rgb; min_neighbour = min(min_neighbour, sample00); max_neighbour = max(max_neighbour, sample00);
    vec3 sample10 = texelFetchOffset(colortex5, iuv, 0, ivec2( 0, -1)).rgb; min_neighbour = min(min_neighbour, sample10); max_neighbour = max(max_neighbour, sample10);
    vec3 sample20 = texelFetchOffset(colortex5, iuv, 0, ivec2( 1, -1)).rgb; min_neighbour = min(min_neighbour, sample20); max_neighbour = max(max_neighbour, sample20);
    vec3 sample01 = texelFetchOffset(colortex5, iuv, 0, ivec2(-1,  0)).rgb; min_neighbour = min(min_neighbour, sample01); max_neighbour = max(max_neighbour, sample01);
    vec3 sample21 = texelFetchOffset(colortex5, iuv, 0, ivec2( 1,  0)).rgb; min_neighbour = min(min_neighbour, sample21); max_neighbour = max(max_neighbour, sample21);
    vec3 sample02 = texelFetchOffset(colortex5, iuv, 0, ivec2(-1,  1)).rgb; min_neighbour = min(min_neighbour, sample02); max_neighbour = max(max_neighbour, sample02);
    vec3 sample12 = texelFetchOffset(colortex5, iuv, 0, ivec2( 0,  1)).rgb; min_neighbour = min(min_neighbour, sample12); max_neighbour = max(max_neighbour, sample12);
    vec3 sample22 = texelFetchOffset(colortex5, iuv, 0, ivec2( 1,  1)).rgb; min_neighbour = min(min_neighbour, sample22); max_neighbour = max(max_neighbour, sample22);

    color = clamp(color, min_neighbour, max_neighbour);

    imageStore(colorimg5, iuv, vec4(color, 1.0));
}