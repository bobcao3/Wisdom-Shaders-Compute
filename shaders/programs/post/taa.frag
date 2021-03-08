uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex10;

/* RENDERTARGETS: 2,10 */

uniform vec2 invWidthHeight;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    vec3 current = texelFetch(colortex2, iuv, 0).rgb;

    vec3 min_neighbour = current;
    vec3 max_neighbour = current;
    
    vec3 sample00 = texelFetchOffset(colortex2, iuv, 0, ivec2(-1, -1)).rgb; min_neighbour = min(min_neighbour, sample00); max_neighbour = max(max_neighbour, sample00);
    vec3 sample10 = texelFetchOffset(colortex2, iuv, 0, ivec2( 0, -1)).rgb; min_neighbour = min(min_neighbour, sample10); max_neighbour = max(max_neighbour, sample10);
    vec3 sample20 = texelFetchOffset(colortex2, iuv, 0, ivec2( 1, -1)).rgb; min_neighbour = min(min_neighbour, sample20); max_neighbour = max(max_neighbour, sample20);
    vec3 sample01 = texelFetchOffset(colortex2, iuv, 0, ivec2(-1,  0)).rgb; min_neighbour = min(min_neighbour, sample01); max_neighbour = max(max_neighbour, sample01);
    vec3 sample21 = texelFetchOffset(colortex2, iuv, 0, ivec2( 1,  0)).rgb; min_neighbour = min(min_neighbour, sample21); max_neighbour = max(max_neighbour, sample21);
    vec3 sample02 = texelFetchOffset(colortex2, iuv, 0, ivec2(-1,  1)).rgb; min_neighbour = min(min_neighbour, sample02); max_neighbour = max(max_neighbour, sample02);
    vec3 sample12 = texelFetchOffset(colortex2, iuv, 0, ivec2( 0,  1)).rgb; min_neighbour = min(min_neighbour, sample12); max_neighbour = max(max_neighbour, sample12);
    vec3 sample22 = texelFetchOffset(colortex2, iuv, 0, ivec2( 1,  1)).rgb; min_neighbour = min(min_neighbour, sample22); max_neighbour = max(max_neighbour, sample22);

    vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;
    vec3 history = texture(colortex10, history_uv).rgb;

    history = clamp(history, min_neighbour, max_neighbour);

    if (history_uv.x < 0.0 || history_uv.x >= 1.0 || history_uv.y < 0.0 || history_uv.y >= 1.0) history = current;

    vec3 color = mix(history, current, 0.18);

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
}