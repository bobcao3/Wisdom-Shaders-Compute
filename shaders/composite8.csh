#version 450 compatibility

#include "/libs/compat.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

const vec2 workGroupsRender = vec2(1.0f, 1.0f);

uniform int frameCounter;
uniform float aspectRatio;

uniform vec2 invWidthHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform usampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex15;

layout (r11f_g11f_b10f) uniform image2D colorimg2;

#include "/libs/transform.glsl"
#include "/libs/noise.glsl"
#include "/libs/raytrace.glsl"
#include "/libs/color.glslinc"

#include "/configs.glsl"

uniform sampler2D depthtex1;

uniform vec3 sunPosition;

// Constants coming from script `shaders/data/brdf_integration.py`
vec3 IntegratedPolynomial(float F0, float alpha, float ndotv)
{
    const float x = 1.0 - alpha;
    const float y = ndotv;

    // Epoch 9 MSE= tensor(0.0283)
    // b tensor([-0.4953,  0.7145,  0.5535, -5.0758,  8.3037, -5.1153])
    // d tensor([ 0.6270,  1.2284,  0.4889, -2.8156,  0.6686, -0.8450,  2.9721])
    // bias tensor([49.0148])
 
    float b1 = -0.4953;
    float b2 = 0.7145;
    float b3 = 0.5535;
    float b4 = -5.0758;
    float b5 = 8.3037;
    float b6 = -5.1153;
    float bias = clamp(min(b1 * x + b2 * x * x, b3 + b4 * y + b5 * y * y + b6 * y * y * y), 0.0, 1.0);
 
    float d0 = 0.6270;
    float d1 = 1.2284;
    float d2 = 0.4889;
    float d3 = -2.8156;
    float d4 = 0.6686;
    float d5 = -0.8450;
    float d6 = 2.9721;
    const float delta = clamp(d0 + d1 * x + d2 * y + d3 * x * x + d4 * x * y + d5 * y * y + d6 * x * x * x, 0.0, 1.0);
    const float scale = delta - bias;

    const float bias_mult = 49.0148;
 
    bias *= clamp(bias_mult * F0, 0.0, 1.0);
    return vec3(F0 * scale + bias);
}

vec3 IntegratedPolynomial2(float metalic, float alpha, float ndotv)
{
    ndotv = sqrt(ndotv);

    float a = 0.4302;
    float b = -1.2618;
    float c = 0.7657;
    float d = 0.0723;
    float e = 1.0;

    return vec3(exp(a * alpha + b - c * ndotv) * (d + e * metalic) * 3.14159);
}

float gaussian[] = float[] (
    0.06136, 0.24477, 0.38774, 0.24477, 0.06136
);

void main()
{
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(iuv) + 0.5) * invWidthHeight;

    float depth = getDepth(iuv);

    if (depth < 1.0)
    {
        vec3 color = texelFetch(colortex2, iuv, 0).rgb;

        vec3 proj_pos = getProjPos(uv, depth);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);
        vec3 world_dir = normalize(world_pos);
        vec3 view_dir = normalize(view_pos);

        vec3 world_normal = texelFetch(colortex7, iuv, 0).rgb;
        vec3 view_normal = normalize(mat3(gbufferModelView) * world_normal);

        uvec2 albedo_specular = texelFetch(colortex6, iuv, 0).xy;

        vec3 albedo = fromGamma(unpackUnorm4x8(albedo_specular.x).rgb);
        vec4 lm_specular_encoded = unpackUnorm4x8(albedo_specular.y);

        float roughness = pow2(1.0 - lm_specular_encoded.b);
        float metalic = lm_specular_encoded.a;

        float converted_metalic = clamp(metalic / (229.0 / 255.0), 0.02, 0.98);

        if (texelFetch(colortex7, iuv, 0).a >= 0.0)
        {
            vec3 indirect = texelFetch(colortex5, ivec2(iuv.x, iuv.y) / 2, 0).rgb;

            vec3 integrated_brdf1 = IntegratedPolynomial(converted_metalic, roughness, max(0.0, dot(-view_dir, view_normal)));
            vec3 integrated_brdf2 = IntegratedPolynomial2(converted_metalic, roughness, max(0.0, dot(-view_dir, view_normal)));
            
            color += integrated_brdf2 * indirect;
        }

        // if (iuv.x <= 256 && iuv.y <= 256)
        //     color = vec3(IntegratedPolynomial(0.9, float(iuv.x) / 256.0, float(iuv.y) / 256.0));

        imageStore(colorimg2, iuv, vec4(color, 1.0));
    }
}