#version 450 compatibility

out flat float median_luma;
out flat int median_index;

uniform usampler2D shadowcolor0;

#include "/libs/color.glslinc"

float getMedianLuma(float target, out int i) // Medium: target = 0.5
{
    i = 128;
    int low = 0;
    int high = 255;

    for (int _k = 0; _k < 8; _k++)
    {
        float s = uintBitsToFloat(texelFetch(shadowcolor0, ivec2(i, 1), 0).r);

        if (s > target)
        {
            high = i;
        }
        else
        {
            low = i;
        }

        i = low + ((high - low) >> 1);
    }

    float median_luma = exp((float(i) - histogram_log_zero) / histogram_log_scale);

    return median_luma;
}

void main()
{
    median_luma = getMedianLuma(0.5, median_index);

    gl_Position = ftransform();
}