#version 430 compatibility

#pragma optimize(on)

#include "/libs/compat.glsl"

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform usampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex15;

layout (r11f_g11f_b10f) uniform image2D colorimg5;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/configs.glsl"
#include "/libs/atmosphere.glsl"


vec4 compute_atmos(vec2 uv, float l_limit)
{
    vec3 proj_pos = getProjPos(uv, 1.0);
    vec3 view_pos = proj2view(proj_pos);
    vec3 world_pos = view2world(view_pos);
    vec3 world_dir = normalize(world_pos);
    
    vec3 color = vec3(0.0);

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

    vec4 skybox_color = scatter(vec3(0.0, cameraPosition.y, 0.0), world_dir, world_sun_dir, l_limit, 0.5, true);

    return skybox_color;
}

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    // z1 = z2 = z3 = z4 = uint((texelFetch(noisetex, iuv_orig & 0xFF, 0).r * 65535.0) * 1000) ^ uint(frameCounter * 11);

    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight * 4.0;

    float l_limit;

    if (uv.x > 1.0)
    {
        if (uv.y > 1.0)
        {
            l_limit = Ra;
        }
        else
        {
            l_limit = 1024.0;
        }
    }
    else
    {
        if (uv.y > 1.0)
        {
            l_limit = 512.0;
        }
        else
        {
            l_limit = 256.0;
        }
    }

    imageStore(colorimg5, iuv, compute_atmos(mod(uv, vec2(1.0)), l_limit));
}