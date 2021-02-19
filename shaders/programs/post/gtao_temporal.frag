uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex9;

/* RENDERTARGETS: 9 */

const bool colortex9Clear = false;

uniform vec2 invWidthHeight;

void main()
{
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = (vec2(iuv) + vec2(0.5)) * invWidthHeight * 2.0;

    if (uv.x >= 1.0 || uv.y >= 1.0) return;

    vec2 history_uv = uv + texelFetch(colortex1, iuv << 1, 0).rg;

    float ao = clamp(texelFetch(colortex0, iuv, 0).r, 0.0, 1.0);

    float history = clamp(texture(colortex9, history_uv * 0.5).r, 0.0, 1.0);

    float weight = 0.2;
    
    if (history_uv.x < 0.0 || history_uv.x >= 1.0 || history_uv.y < 0.0 || history_uv.y >= 1.0) weight = 1.0;

    ao = mix(history, ao, weight);

    gl_FragData[0] = vec4(ao);
}