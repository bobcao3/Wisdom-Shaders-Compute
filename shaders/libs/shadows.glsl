// float VSM(float t, vec2 uv)
// {
//     vec2 means = texture(shadowcolor1, uv).rg;
//     float e_x = means.x;
//     float var = means.y - e_x * e_x;

//     float p_max = (var + 1e-7) / (var + pow2(max(0.0, t - e_x)) + 1e-7);

//     const float c = 500;

//     float depth_test_exp = clamp(exp(-c * (t - e_x)), 0.0, 1.0);

//     return min(p_max, depth_test_exp);
// }

#include "/configs.glsl"

uniform sampler2D shadowtex1;

float shadowStep(float s, float edge, float bias)
{
    return clamp((s - edge + bias) * 100000.0, 0.0, 1.0);
}

float shadowTexSmooth(in vec3 spos, out float depth, float bias) {
    if (clamp(spos, vec3(0.01), vec3(0.99)) != spos) return 1.0;

    const vec2 uv = spos.xy * shadowMapResolution;
    const vec2 uv_lower = floor(uv);
    const vec2 offset = uv - uv_lower;

    const float d00 = texelFetchOffset(shadowtex1, ivec2(uv_lower), 0, ivec2(0, 0)).r;
    const float d01 = texelFetchOffset(shadowtex1, ivec2(uv_lower), 0, ivec2(0, 1)).r;
    const float d10 = texelFetchOffset(shadowtex1, ivec2(uv_lower), 0, ivec2(1, 0)).r;
    const float d11 = texelFetchOffset(shadowtex1, ivec2(uv_lower), 0, ivec2(1, 1)).r;

    const float min_depth = min(min(d00, d01), min(d10, d11));
    const float max_depth = max(max(d00, d01), max(d10, d11));

    // bias = max(bias * 20.0, max_depth - min_depth);

    const float s00 = shadowStep(d00, spos.z, bias);
    const float s01 = shadowStep(d01, spos.z, bias);
    const float s10 = shadowStep(d10, spos.z, bias);
    const float s11 = shadowStep(d11, spos.z, bias);

    const float s = mix(
        mix(s00, s01, offset.y),
        mix(s10, s11, offset.y),
        offset.x);

    return s;
}