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
uniform sampler2D colortex9;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

uniform usampler2D shadowcolor0;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"
#include "/libs/color.glslinc"

#include "/configs.glsl"

/* RENDERTARGETS: 5,9,12 */

#define MAX_SVGF_TEMPORAL_LENGTH 64 // [16 32 48 64 80 96 112 128]

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.xy) * 2;
    ivec2 iuv_orig = ivec2(gl_FragCoord.xy);
    vec2 uv = (vec2(iuv) + 1.0) * invWidthHeight;

    if (uv.y > 1.0)
    {
        if (uv.x > 1.0)
        {
            vec4 v = texelFetch(colortex5, iuv_orig, 0);
            gl_FragData[0] = v;
            gl_FragData[2] = v;
        }
        return;
    }

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

    float view_z, history_length = 0.0;

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos); view_z = view_pos.z;
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 curr_color = texelFetch(colortex5, iuv_orig, 0).rgb;
        color = curr_color;

        vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;
        float weight = 0.06;
        
        if (history_uv.x < 0.0 || history_uv.y < 0.0 || history_uv.x > 1.0 || history_uv.y > 1.0) weight = 1.0;

        ivec2 history_uv_iuv = ivec2(history_uv * 0.5 * vec2(viewWidth, viewHeight));

        vec4 history = texture(colortex12, history_uv * 0.5);
        history_length = texture(colortex9, history_uv * 0.5).r;

        if (isNanInf(history)) history = vec4(0.0);

        float depth_diff = abs((view_pos.z - history.a) / view_pos.z);
        if (depth_diff > 0.1)
        {
            weight = 1.0;
        }

        history_length = clamp((weight > 0.9) ? 1.0 : history_length + 1.0, 1.0, float(MAX_SVGF_TEMPORAL_LENGTH));

        weight = 1.0 / history_length;

        if (squared)
        {
            float x = luma(color);
            
            vec2 last_moments = texture(colortex12, vec2(history_uv.x + 1.0, history_uv.y) * 0.5).rg;
            float ema_last = last_moments.x;
            float ema2_last = last_moments.y;

            float ema = ema_last * (history_length - 1.0) * weight + x * weight;
            float ema2 = ema2_last * (history_length - 1.0) * weight + pow2(x) * weight;
            float emvar = abs(pow2(ema) - ema2);

            if (history_length < 8)
            {
                float x2 = 0.0;
                float x = 0.0;
                for (int i = -2; i <= 2; i++)
                {
                    for (int j = -2; j <= 2; j++)
                    {
                        vec3 s = texelFetch(colortex5, iuv_orig + ivec2(i, j), 0).rgb;
                        float l = luma(s);
                        x += l;
                        x2 += l * l;
                    }
                }
                ema = x * (1.0 / 25.0);
                ema2 = ema * ema;
                emvar = x2 * (1.0 / 25.0) - ema * ema + 0.5;
            }

            float history_factor = 8.0 - history_length * (7.0 / 64.0);
            emvar = max((history_factor - 1.0) * 0.1, emvar * history_factor);

            temporal = vec3(ema, ema2, 0.0);
            color = vec3(emvar);
        }
        else
        {
            color = history.rgb * (history_length - 1.0) * weight + color * weight;
            temporal = color;
        }

        if (curr_color.r > 1e5) color = vec3(1.0, 0.0, 0.0);

    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(history_length, 0.0, 0.0, 1.0);    
    gl_FragData[2] = vec4(temporal, view_z);
}