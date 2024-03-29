#version 430 compatibility

#pragma optimize(on)

layout (local_size_x = 32, local_size_y = 32) in;

const vec2 workGroupsRender = vec2(0.3f, 0.13f);

#include "/libs/compat.glsl"

#define DISABLE_MIE

uniform vec2 invWidthHeight;

uniform sampler2D colortex3;


#include "/libs/color.glslinc"
#include "/libs/atmosphere.glsl"

uniform int biomeCategory;

uniform vec3 fogColor;

uniform int frameCounter;

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    if (frameCounter % 2 == 1) {
        vec4 skybox = vec4(0.0);
    
        if (biomeCategory != 16) {
            vec3 dir = project_uv2skybox(vec2(iuv) * invWidthHeight);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, 0.9, false) * 0.5;

            skybox.rgb += vec3(dot(skybox.rgb, vec3(1.0)) * rainStrength2);
        } else {
            skybox = vec4(fromGamma(fogColor), 0.0);
        }

        imageStore(colorimg3, iuv, skybox);
    }

}