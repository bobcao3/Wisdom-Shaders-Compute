#include "/libs/compat.glsl"

uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor1;

float gaussian[] = float[] (
    0.06136, 0.24477, 0.38774, 0.24477, 0.06136
);

/* RENDERTARGETS: 1 */

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float e_x = 0.0;
    float e_x2 = 0.0;

    for (int i = -2; i <= 2; i++)
    {
        ivec2 sample_uv = iuv + DIR(i);
        
#ifdef INITIAL
        float depth = texelFetch(shadowtex1, sample_uv, 0).r;

        e_x += depth * gaussian[i + 2];
        e_x2 += (depth * depth) * gaussian[i + 2];
#else
        vec2 s = texelFetch(shadowcolor1, sample_uv, 0).rg;
        e_x += s.x * gaussian[i + 2];
        e_x2 += s.y * gaussian[i + 2];
#endif
    }

    gl_FragData[0] = vec4(e_x, e_x2, 1.0, 1.0);
}