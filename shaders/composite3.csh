#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(0.5f, 0.5f);

uniform sampler2D colortex5;

float gaussian[] = float[] (
    0.2709612742154403, 0.45807745156911933, 0.2709612742154403
);

layout (rgba16f) uniform image2D colorimg5;

int getIndex(ivec2 uv)
{
    return uv.y * int(gl_WorkGroupSize.x + 4) + uv.x;
}

uniform float viewWidth;

shared float lds_x[(gl_WorkGroupSize.x + 2) * (gl_WorkGroupSize.y + 2)];

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy) + ivec2(viewWidth * 0.5, 0);
    ivec2 local_id = ivec2(gl_LocalInvocationID.xy) + 2;

    // Load the padding
    {
        int index = int(gl_LocalInvocationIndex);
        const int padded_width = int(gl_WorkGroupSize.x + 2);
        const int local_size = int(gl_WorkGroupSize.x * gl_WorkGroupSize.y);
        const int block_size = int((gl_WorkGroupSize.x + 2) * (gl_WorkGroupSize.y + 2));

        ivec2 local_xy = ivec2((index % padded_width) - 1, (index / padded_width) - 1);
        ivec2 pad_uv = ivec2(gl_WorkGroupSize.xy * gl_WorkGroupID.xy) + local_xy + ivec2(viewWidth * 0.5, 0);
        lds_x[getIndex(local_xy + 2)] = texelFetch(colortex5, pad_uv, 0).r;

        while (block_size > index + local_size)
        {
            index += local_size;

            ivec2 local_xy = ivec2((index % padded_width) - 1, (index / padded_width) - 1);
            ivec2 pad_uv = ivec2(gl_WorkGroupSize.xy * gl_WorkGroupID.xy) + local_xy + ivec2(viewWidth * 0.5, 0);
            lds_x[getIndex(local_xy + 2)] = texelFetch(colortex5, pad_uv, 0).r;
        }
    }

    barrier();

    float x = 0.0;

    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float d = lds_x[getIndex(local_id + ivec2(i, j))];
            float weight = gaussian[i + 1] * gaussian[j + 1];
            x += d * weight;
        }
    }

    imageStore(colorimg5, iuv, vec4(x, 0.0, 0.0, 1.0));
}