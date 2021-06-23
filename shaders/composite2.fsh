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

// #define GI_NO_CLIP

#ifdef GI_NO_CLIP
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
#endif

#define FIREFLY_FILTER

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
            gl_FragData[1] = v;
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

    float view_z;

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos); view_z = view_pos.z;
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 curr_color = texelFetch(colortex5, iuv_orig, 0).rgb;
        color = curr_color;

#ifdef FIREFLY_FILTER
        vec3 s0 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2(-1, -1)).rgb;
        vec3 s1 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2( 0, -1)).rgb;
        vec3 s2 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2( 1, -1)).rgb;
        vec3 s3 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2(-1,  0)).rgb;
        vec3 s4 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2( 1,  0)).rgb;
        vec3 s5 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2(-1,  1)).rgb;
        vec3 s6 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2( 0,  1)).rgb;
        vec3 s7 = texelFetchOffset(colortex5, iuv_orig, 0, ivec2( 1,  1)).rgb;
        vec3 min_bound = min(min(min(s0, s1), min(s2, s3)), min(min(s4, s5), min(s6, s7)));
        vec3 max_bound = max(max(max(s0, s1), max(s2, s3)), max(max(s4, s5), max(s6, s7)));
        vec3 color_unclamped = color;
        color = clamp(color, min_bound * 0.5 - 0.2, max_bound * 3.0 + 3.0);
#endif

        vec2 history_uv = uv + texelFetch(colortex1, iuv, 0).rg;
        ivec2 history_iuv = ivec2((history_uv) * vec2(viewWidth, viewHeight) * 0.5);
        float weight = 0.09;
        
        if (history_uv.x < 0.0 || history_uv.y < 0.0 || history_uv.x > 1.0 || history_uv.y > 1.0) weight = 1.0;

        if (squared)
        {
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = vec3(luma, luma * luma, 1);
            history_uv.x += 1.0;
        }

        // vec4 history = texture(colortex12, history_uv * 0.5);
        // vec4 history = texelFetch(colortex12, ivec2((history_uv) * vec2(viewWidth, viewHeight) * 0.5), 0);
        vec4 history = texelFetch(colortex12, history_iuv, 0);

        if (isnan(history.x)) history = vec4(0.0);

        float depth_diff = abs((view_pos.z - history.a) / view_pos.z);
        if (depth_diff > 0.1)
        {
            weight = 1.0;
        }
        else
        {
            weight *= 0.5;
        }

#ifndef GI_NO_CLIP
        if (squared)
        {
            if (weight > 0.9)
            {
                color = vec3(0.0, 1.0, 1.0);
            }
            // else
            // {
            //     color += history.rgb;
            //     if (color.b > 16.0) color *= 0.5;
            // }
            color = mix(history.rgb, color, weight);
        }
        else
        {
            color = mix(history.rgb, color, weight);
        }
#else
        float history_length;
        
        color += history.rgb;

        if (squared)
        {
            history_length = color.b;
        }
        else
        {
            history_length = texelFetch(colortex12, ivec2((history_uv + vec2(1.0, 0.0)) * vec2(viewWidth, viewHeight) * 0.5), 0).b;
        }
#endif

        temporal = color;

// #ifdef FIREFLY_FILTER
//         if (!squared)
//         {
//             temporal = mix(history.rgb, color_unclamped, weight);
//         }
// #endif

#ifndef GI_NO_CLIP
        if (squared)
        {
            color = vec3(abs((color.g) - pow2(color.r)));
        }
#else
        if (squared)
        {
            color = vec3(abs((color.g / history_length) - pow2(color.r / history_length)));
        }
        else
        {
            color = color / max(0.01, history_length);
        }
#endif
    }

#ifdef GI_NO_CLIP
    if (
        distance(cameraPosition, previousCameraPosition) > 1e-5 ||
        distance(gbufferProjection[0], gbufferPreviousProjection[0]) > 1e-5 ||
        distance(gbufferProjection[1], gbufferPreviousProjection[1]) > 1e-5 ||
        distance(gbufferProjection[2], gbufferPreviousProjection[2]) > 1e-5 ||
        distance(gbufferProjection[3], gbufferPreviousProjection[3]) > 1e-5 ||
        distance(gbufferModelView[0], gbufferPreviousModelView[0]) > 1e-5 ||
        distance(gbufferModelView[1], gbufferPreviousModelView[1]) > 1e-5 ||
        distance(gbufferModelView[2], gbufferPreviousModelView[2]) > 1e-5 ||
        distance(gbufferModelView[3], gbufferPreviousModelView[3]) > 1e-5
    ) {
        color = vec3(0.0);
        temporal = vec3(0.0);
    }
#endif

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(temporal, view_z);
}