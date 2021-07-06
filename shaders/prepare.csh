#version 430 compatibility

#pragma optimize(on)

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(0.25f, 0.5f);

uniform int frameCounter;

uniform vec2 invWidthHeight;

uniform sampler2D colortex3;

#include "/libs/compat.glsl"

#include "/libs/atmosphere.glsl"

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    if (iuv.x <= min(128, int(viewWidth) >> 2) && iuv.y <= min(384, int(viewHeight) >> 1) && frameCounter % 2 == 0)
    {
        vec4 skybox = vec4(0.0);
    
        vec2 uv = (vec2(iuv) * invWidthHeight) * max(vec2(4.0), vec2(viewWidth / 128.0, 2.0 * viewHeight / 384.0));
        skybox.rg = clamp(vec2(densitiesMap(uv)), vec2(0.0), vec2(200.0));
        skybox.ba = vec2(0.0);
    
        imageStore(colorimg3, iuv + ivec2(0, int(viewHeight) >> 1), skybox);
    }

}