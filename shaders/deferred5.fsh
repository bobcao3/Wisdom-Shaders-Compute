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
uniform usampler2D colortex6;
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

vec4 sampleHistory(ivec2 iuv, out float history_length)
{
    history_length = clamp(texelFetch(colortex9, iuv, 0).r, 0.0, float(MAX_SVGF_TEMPORAL_LENGTH));
    vec4 history = texelFetch(colortex12, iuv, 0);
    if (isNanInf(history))
    {
        history = vec4(0.0);
        history_length = 0.0;
    }
    return history;
}

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

    float dist, history_length = 0.5;

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        dist = length(view_pos.xyz);

        vec3 curr_color = texelFetch(colortex5, iuv_orig, 0).rgb;
        color = curr_color;

        vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;
        
        vec2 history_iuv = history_uv * 0.5 * vec2(viewWidth, viewHeight) - vec2(0.5);
        vec2 history_iuv_frac = fract(history_iuv);

        float history_length00;
        vec4 history00 = sampleHistory(ivec2(history_iuv), history_length00);
        float history_length01;
        vec4 history01 = sampleHistory(ivec2(history_iuv) + ivec2(0, 1), history_length01);
        float history_length10;
        vec4 history10 = sampleHistory(ivec2(history_iuv) + ivec2(1, 0), history_length10);
        float history_length11;
        vec4 history11 = sampleHistory(ivec2(history_iuv) + ivec2(1, 1), history_length11);

        float weight00 = float(abs((dist - history00.a) / dist) < 0.05) * (1.0 - history_iuv_frac.x) * (1.0 - history_iuv_frac.y);
        float weight01 = float(abs((dist - history01.a) / dist) < 0.05) * (1.0 - history_iuv_frac.x) * (      history_iuv_frac.y);
        float weight10 = float(abs((dist - history10.a) / dist) < 0.05) * (      history_iuv_frac.x) * (1.0 - history_iuv_frac.y);
        float weight11 = float(abs((dist - history11.a) / dist) < 0.05) * (      history_iuv_frac.x) * (      history_iuv_frac.y);

        float total_weight = weight00 + weight01 + weight10 + weight11 + 1e-4;
        vec4 history = (history00 * weight00 + history01 * weight01 + history10 * weight10 + history11 * weight11) / total_weight;
        float history_length = (history_length00 * weight00 + history_length01 * weight01 + history_length10 * weight10 + history_length11 * weight11) / total_weight;
        history_length = clamp((total_weight < 0.01) ? 1.0 : history_length + 1.0, 1.0, float(MAX_SVGF_TEMPORAL_LENGTH));

        if (history_uv.x < 0.0 || history_uv.y < 0.0 || history_uv.x > 1.0 || history_uv.y > 1.0) history_length = 1.0;

        float weight = 1.0 / max(1.0, history_length - 1.0);

        if (squared)
        {
            float x = luma(color);
            
            vec2 last_moments = texture(colortex12, vec2(history_uv.x + 1.0, history_uv.y) * 0.5).rg;
            float ema_last = last_moments.x;
            float ema2_last = last_moments.y;

            float ema = mix(ema_last, x, weight);
            float ema2 = mix(ema2_last, x, weight);
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

            float history_factor = weight * 4.0;
            emvar = max(emvar * 0.1, emvar * history_factor);

            temporal = vec3(ema, ema2, 0.0);
            color = vec3(emvar);
        }
        else
        {
            color = mix(history.rgb, color, weight);
            temporal = color;
        }

        if (curr_color.r > 1e5) color = vec3(1.0, 0.0, 0.0);

        gl_FragData[1] = vec4(history_length, 0.0, 0.0, 1.0);
    }
    else
    {
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[2] = vec4(temporal, dist);
}