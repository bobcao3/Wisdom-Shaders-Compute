uniform sampler2D colortex9;

vec3 GTAOMultiBounce(float visibility, vec3 albedo)
{
 	vec3 a =  2.0404 * albedo - 0.3324;   
    vec3 b = -4.7951 * albedo + 0.6417;
    vec3 c =  2.7552 * albedo + 0.6903;
    
    vec3 x = vec3(visibility);
    return max(x, ((x * a + b) * x + c) * x);
}

vec3 getAO(ivec2 iuv, float depth, vec3 albedo)
{
    float ao = 0.0001;
    float weight = 0.0001;

    if (depth >= 1.0 || depth <= 0.7) return vec3(1.0);

    float linear_depth = linearizeDepth(depth);

    ivec2 iuv_half = iuv >> 1;
    
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float ao_sample = texelFetch(colortex9, iuv_half + ivec2(i, j), 0).r;
            float depth_sample = texelFetch(colortex4, iuv_half + ivec2(i, j), 0).r;

            float depth_diff = (linear_depth - linearizeDepth(depth_sample)) / linear_depth;

            float weight_sample = exp(-depth_diff * depth_diff * 9000.0) * exp(-float(i * i + j * j)) * float(depth_sample < 1.0);

            ao += ao_sample * weight_sample;
            weight += weight_sample;
        }
    }

    ao /= weight;

    return GTAOMultiBounce(ao, albedo);
}