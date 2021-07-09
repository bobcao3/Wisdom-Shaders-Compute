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
    // b tensor([ 0.7437,  3.1780, -0.1140, -1.4741, 10.4470, -4.8231])
    // d tensor([-8.0785,  5.2565, -0.7135,  1.5604, 17.2632,  8.3191, -2.7194])
    // bias tensor([121.4076])
 
    float b1 = -0.1688;
    float b2 = 1.895;
    float b3 = 0.9903;
    float b4 = -4.853;
    float b5 = 8.404;
    float b6 = -5.069;
    float bias = clamp(min(b1 * x + b2 * x * x, b3 + b4 * y + b5 * y * y + b6 * y * y * y), 0.0, 1.0);
 
    float d0 = 0.6045;
    float d1 = 1.699;
    float d2 = -0.5228;
    float d3 = -3.603;
    float d4 = 1.404;
    float d5 = 0.1939;
    float d6 = 2.661;
    const float delta = clamp(d0 + d1 * x + d2 * y + d3 * x * x + d4 * x * y + d5 * y * y + d6 * x * x * x, 0.0, 1.0);
    const float scale = delta - bias;

    const float bias_mult = 14.0;
 
    bias *= clamp(bias_mult * F0, 0.0, 1.0);
    return vec3(F0 * scale + bias);
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

        float F0 = clamp(metalic / (229.0 / 255.0), 0.02, 1.0);

        if (texelFetch(colortex7, iuv, 0).a >= 0.0)
        {
            vec3 indirect = texelFetch(colortex5, ivec2(iuv.x, iuv.y) / 2, 0).rgb;

            // vec3 integrated_brdf = IntegratedPolynomial(F0, roughness, max(0.0, dot(-view_dir, view_normal)));
            color += indirect;
        }

        // if (iuv.x <= 256 && iuv.y <= 256)
        //     color = vec3(IntegratedPolynomial(0.9, float(iuv.x) / 256.0, float(iuv.y) / 256.0));

        imageStore(colorimg2, iuv, vec4(color, 1.0));
    }
}