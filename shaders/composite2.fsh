#version 450 compatibility

#include "/libs/compat.glsl"

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

uniform usampler2D shadowcolor0;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"

#include "/configs.glsl"

/* RENDERTARGETS: 5,12 */

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.xy) * 2;
    ivec2 iuv_orig = ivec2(gl_FragCoord.xy);
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    if (uv.y > 1.0) return;

    bool squared = false;
    if (uv.x > 1.0)
    {
        squared = true;
        uv.x -= 1.0;
        iuv_orig.x -= int(viewWidth * 0.5);
        iuv.x -= int(viewWidth);
    }

    float depth = texelFetch(colortex4, iuv_orig, 0).r;

    vec3 temporal = vec3(0.0);
    vec3 color = vec3(0.0);

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 curr_color = texelFetch(colortex5, iuv_orig, 0).rgb;
        color = curr_color;

        vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;

        if (squared)
        {
            color = vec3(dot(color, vec3(0.2126, 0.7152, 0.0722)));
            color *= color;
            history_uv.x += 1.0;
        }

        vec3 history = texture(colortex12, history_uv / 2).rgb;

        if (isnan(history.x)) history = vec3(0.0);

        color = mix(history, color, 0.1);

        temporal = color;

        if (squared)
        {
            float x2 = color.r; // Not correct luma but whatever
            vec3 color_temporal = mix(
                texture(colortex12, (history_uv - vec2(1.0, 0.0)) / 2).rgb,
                curr_color,
                0.1
            );
            float x = dot(color_temporal, vec3(0.2126, 0.7152, 0.0722));

            color = vec3(abs(x2 - x * x));
        }
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(temporal, 1.0);
}