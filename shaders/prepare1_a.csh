#version 430 compatibility

#pragma optimize(on)

layout (local_size_x = 4, local_size_y = 4) in;

layout (r11f_g11f_b10f) uniform image2D colorimg3;

const ivec3 workGroups = ivec3(1, 1, 1);

#include "libs/compat.glsl"

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
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), world_sun_dir, world_sun_dir, Ra, 0.9, false);

            skybox.rgb *= skybox.a * (1.0 - rainStrength2 * 0.97) * abs(world_sun_dir.y);
        } else {
            skybox = vec4(fromGamma(fogColor), 0.0);
        }

        imageStore(colorimg3, ivec2(viewWidth - 1, 0), skybox);
    }

}