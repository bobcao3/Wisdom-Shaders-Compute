#include "/libs/color.glslinc"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

float gaussian[] = float[] (
    0.07515427803139076,
    0.12487059853370433,
    0.16933972985404783,
    0.18743754835839238,
    0.16933972985404783,
    0.12487059853370433,
    0.07515427803139076
);

layout (r16f) uniform image2D colorimg0;

int getIndex(ivec2 uv)
{
    return uv.y * int(gl_WorkGroupSize.x + 6) + uv.x;
}

shared float lds_x[(gl_WorkGroupSize.x + 6) * (gl_WorkGroupSize.y + 6)];

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 local_id = ivec2(gl_LocalInvocationID.xy) + 3;

    // Load the padding
    {
        int index = int(gl_LocalInvocationIndex);
        const int padded_width = int(gl_WorkGroupSize.x + 6);
        const int local_size = int(gl_WorkGroupSize.x * gl_WorkGroupSize.y);
        const int block_size = int((gl_WorkGroupSize.x + 6) * (gl_WorkGroupSize.y + 6));

        ivec2 local_xy = ivec2((index % padded_width) - 3, (index / padded_width) - 3);
        ivec2 pad_uv = ivec2(gl_WorkGroupSize.xy * gl_WorkGroupID.xy) + local_xy;
        lds_x[getIndex(local_xy + 3)] = SOURCE(pad_uv);

        while (block_size > index + local_size)
        {
            index += local_size;

            ivec2 local_xy = ivec2((index % padded_width) - 3, (index / padded_width) - 3);
            ivec2 pad_uv = ivec2(gl_WorkGroupSize.xy * gl_WorkGroupID.xy) + local_xy;
            lds_x[getIndex(local_xy + 3)] = SOURCE(pad_uv);
        }
    }

    barrier();

    float L = 0.0;
    float total_weight = 0.0;

    for (int i = -3; i <= 3; i++)
    {
        for (int j = -3; j <= 3; j++)
        {
            float l = lds_x[getIndex(local_id + ivec2(i, j))];
            float weight = gaussian[i + 3] * gaussian[j + 3];
            L += l * weight;
            total_weight += weight;
        }
    }

    imageStore(colorimg0, iuv, vec4(L / total_weight));
}