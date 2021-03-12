#include "/libs/compat.glsl"

uniform int frameCounter;

#ifdef VERTEX

out vec4 color;
out f16vec2 uv;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

attribute vec4 mc_Entity;

uniform mat4 gbufferProjection;

uniform float near;
uniform float far;
uniform float aspectRatio;

bool intersect(vec3 orig, vec3 D) { 
    // Test whether a line crosses the view frustum
    
    float tan_theta_h = 1.0 / gbufferProjection[1][1];
    float tan_theta = sqrt(pow2(tan_theta_h) + pow2(tan_theta_h * aspectRatio));
    float theta = atan(tan_theta);
    float cos_theta = cos(theta);
    float cos2_theta = cos_theta * cos_theta;

    const vec3 C = vec3(0.0, 0.0, 1.0);
    const vec3 V = vec3(0.0, 0.0, -1.0);
    vec3 CFar = vec3(0.0, 0.0, -far);
    vec3 CO = orig - C;

    vec3 isectFar = orig + D * ((-far - orig.z) / D.z);
    if (D.z < 0.0 && length(isectFar.xy) < (far + 1.0) * tan_theta) return true;

    float a = pow2(-D.z) - cos2_theta;
    float b = 2.0 * ((-D.z) * (-CO.z) - dot(D, CO) * cos2_theta);
    float c = pow2(-CO.z) - dot(CO, CO) * cos2_theta;

    float det = b * b - 4.0 * a * c;

    if (det < 0) return false;

    det = sqrt(det);
    float inv2a = 1.0 / (2.0 * a);
    float t1 = (-b - det) * inv2a;
    float t2 = (-b + det) * inv2a;

    float t = t1;
    if (t < 0.0 || t2 > 0.0 && t2 < t) t = t2;
    if (t < 0.0) return false;

    vec3 CP = orig + t * D - C;
    if (-CP.z < 0.0 || -CP.z > far + 1.0) return false;

    return true;
}

void main() {
    vec4 input_pos = gl_Vertex;

    uv = f16vec2(mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st);
    color = vec4(gl_Color);

    vec4 shadow_view_pos = gl_ModelViewMatrix * input_pos;

    gl_Position = gl_ProjectionMatrix * shadow_view_pos;

    gl_Position.xy /= length(gl_Position.xy) * 0.85 + 0.15;
    gl_Position.z *= 0.3;
}

#else

in vec4 color;
in f16vec2 uv;

uniform sampler2D tex;

#include "/configs.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    gl_FragData[0] = color * texture(tex, uv);
}

#endif