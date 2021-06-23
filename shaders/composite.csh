#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

layout (r11f_g11f_b10f) uniform image2D colorimg2;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"

#include "/configs.glsl"

uniform sampler2D depthtex1;

uniform vec3 sunPosition;

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    vec4 transparent = texelFetch(colortex11, iuv, 0);

    if (transparent.a > 0.01)
    {
        z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);
        getRand();

        float depth = texelFetch(depthtex0, iuv, 0).r;

        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);

        float hash1d = texelFetch(colortex15, (iuv + ivec2(WeylNth(frameCounter & 0xFFFF) * 256)) & 0xFF, 0).r;
        int rand1d = (frameCounter & 0xFFFF) + int(bayer16(vec2(iuv)) * 256.0);
        
        vec3 color = texelFetch(colortex5, iuv, 0).rgb;

        vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

        float depth1 = texelFetch(depthtex1, iuv, 0).r;

        float depth_diff = abs(linearizeDepth(depth1) - linearizeDepth(depth)) * far * 0.5;

        float weight = 1.0;
        for (int i = 0; i < 16; i++)
        {
            vec2 offset = vec2(getRand(), getRand());
            float weight_s = 1.0 / (1.0 + 6.0 * offset.x * offset.x);

            offset.x *= 2.0 * PI;
            offset = vec2(cos(offset.x), sin(offset.x)) * offset.y;
            offset.y *= aspectRatio;

            color.rgb += texture(colortex5, uv + 0.01 * offset * clamp(transparent.a * 0.05 * depth_diff, 0.0, 1.0)).rgb * weight_s;
            weight += weight_s;
        }
        color.rgb /= weight;

        color.rgb *= transparent.rgb / transparent.a * 0.8 + 0.2;

        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        color.rgb *= 1.0 - pow(1.0 - abs(dot(normalize(view_pos), view_normal)), 3.0);

        imageStore(colorimg2, iuv, vec4(color, 1.0));
    }
    else
    {
        imageStore(colorimg2, iuv, vec4(texelFetch(colortex5, iuv, 0).rgb, 1.0));
    }
}