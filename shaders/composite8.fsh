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

/* RENDERTARGETS: 2 */

float gaussian[] = float[] (
    0.06136, 0.24477, 0.38774, 0.24477, 0.06136
);

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    float depth = texelFetch(depthtex0, iuv, 0).r;

    vec3 color = texelFetch(colortex2, iuv, 0).rgb;
    vec3 temporal = vec3(0.0);

    // color *= 0.0;

    if (depth < 1.0)
    {
        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 albedo = texelFetch(colortex6, iuv, 0).rgb;
        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        float world_depth = linearizeDepth(depth);
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        vec3 indirect = vec3(0.0);
        float weight = 0.0001;

        for (int i = 0; i <= 1; i++)
        {
            for (int j = 0; j <= 1; j++)
            {
                vec3 sample_normal = texelFetch(colortex7, iuv + ivec2(i * 2, j * 2), 0).rgb;
                float sample_depth = linearizeDepth(texelFetch(colortex4, (iuv / 2) + ivec2(i, j), 0).r);
                float sample_weight = gaussian[i + 2] * gaussian[j + 2]
                     * pow3(abs(dot(sample_normal, world_normal)))
                     * exp(-abs(sample_depth - world_depth) / max(0.01, world_depth) * 128);
                indirect += texelFetch(colortex5, iuv / 2 + ivec2(i, j), 0).rgb * sample_weight;
                weight += sample_weight;
            }
        }

        indirect /= weight;

        color += indirect * albedo;

        // color = indirect;
    }

    // color = texelFetch(colortex5, iuv, 0).rgb;

    gl_FragData[0] = vec4(color, 1.0);
}