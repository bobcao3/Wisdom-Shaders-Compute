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
// uniform sampler2D shadowcolor1;

uniform vec3 shadowLightPosition;

#include "/libs/shadows.glsl"
#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"
#include "/libs/lighting.glsl"

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

        vec4 lm_specular_encoded = texelFetch(colortex8, iuv, 0).rgba;

        vec2 lmcoord = lm_specular_encoded.rg;

        float roughness = pow2(1.0 - lm_specular_encoded.b);
        float metalic = lm_specular_encoded.a;

        vec3 indirect = vec3(0.0);
        float weight = 0.0001;

        for (int i = -1; i <= 1; i++)
        {
            for (int j = -1; j <= 1; j++)
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

        vec3 F0 = getF0(metalic);

        vec3 F = F0 + pow5((1.0 - max(dot(-normalize(view_dir), view_normal), 0.0)) * sqrt(1.0 - roughness)) * (1.0 - F0);

        vec3 kS = F;
        vec3 kD = 1.0 - kS;
        kD *= 1.0 - F0.r;

        indirect *= kD;

        color += indirect * albedo;

        color = indirect;
    }

    // color = texelFetch(colortex5, iuv, 0).rgb;

    // if (uv.x < 0.5 && uv.y >= 0.5) color = texelFetch(colortex9, iuv - ivec2(0, viewHeight / 2), 0).rrr / 64.0;

    gl_FragData[0] = vec4(color, 1.0);
}