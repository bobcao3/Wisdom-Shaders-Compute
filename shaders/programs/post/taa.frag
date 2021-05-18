uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex10;

/* RENDERTARGETS: 2,10 */

uniform vec2 invWidthHeight;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;

#include "/libs/color.glslinc"

uniform vec2 taaOffset;
uniform vec2 last_taaOffset;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    vec3 current = texelFetch(colortex2, iuv, 0).rgb;

/*
    #define SAMPLES_CUTOFF 2048

    vec3 dist0 = cameraPosition - previousCameraPosition;
    vec4 dist1 = gbufferModelView[0] - gbufferPreviousModelView[0];
    vec4 dist2 = gbufferModelView[1] - gbufferPreviousModelView[1];
    vec4 dist3 = gbufferModelView[2] - gbufferPreviousModelView[2];
    vec4 dist4 = gbufferModelView[3] - gbufferPreviousModelView[3];    

    if (dot(dist0, dist0) + dot(dist1, dist1) + dot(dist2, dist2) + dot(dist3, dist3) + dot(dist4, dist4) < 0.000001)
    {
        vec4 pixelHistory = texelFetch(colortex10, iuv, 0);

        if (pixelHistory.a < 0.1) pixelHistory = vec4(0.0);
    
        if (pixelHistory.a < SAMPLES_CUTOFF) pixelHistory += vec4(current, 1.0);
        gl_FragData[0] = vec4(pixelHistory.rgb / pixelHistory.a, 1.0);
        gl_FragData[1] = pixelHistory;
    }
    else
    {
  */
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

        float history_local_luma = texelFetch(colortex10, iuv, 0).a;

        history = clamp(history, min_neighbour, max_neighbour);

        if (history_uv.x < 0.0 || history_uv.x >= 1.0 || history_uv.y < 0.0 || history_uv.y >= 1.0) history = current;

        float history_L = luma(history);
        float current_L = luma(current);

        history /= history_L + 0.001;
        current /= current_L + 0.001;

        float new_L = mix(history_L, current_L, 0.1);

        vec3 color = mix(history, current, 0.2) * new_L;

        gl_FragData[0] = vec4(color, 0);
        gl_FragData[1] = vec4(color, log2(luma(color) * 500.0 + 0.001));
    //}

}