#define SSPT_SAMPLES 16

// #define SSR_2D

ivec2 raytrace(in vec3 vpos, in vec2 iuv, in vec3 dir, float stride, float stride_multiplier, float zThickness, inout int lod, bool refine) {

#ifndef SSR_2D
    float step_length = 0.1 * abs(vpos.z);
    float start_bias = 0.1;

    vec3 vpos_step = vpos + dir * start_bias;
    vec3 vpos_sample = vpos_step;
    
    ivec2 hit_iuv = ivec2(-1);

    float last_z = vpos.z;

    float dither = getRand();

    for (int i = 0; i < SSPT_SAMPLES; i++)
    {
        vpos_sample = vpos_step + dither * step_length * dir;

        vec3 proj_pos_sample = view2proj(vpos_sample);
        vec2 uv_sample = proj_pos_sample.st * 0.5 + 0.5;
        
        if (uv_sample.x < 0.0 || uv_sample.x > 1.0 || uv_sample.y < 0.0 || uv_sample.y > 1.0) break;

        ivec2 iuv_sample = ivec2(uv_sample * vec2(viewWidth, viewHeight) * 0.5);

        float depth_sample = texelFetch(colortex4, iuv_sample, 0).r;
        float viewz_sample = proj2view(getProjPos(ivec2(iuv_sample), depth_sample)).z;

        if (viewz_sample >= vpos_sample.z && viewz_sample < last_z + step_length)
        {
            hit_iuv = iuv_sample * 2;
            break;
        }

        last_z = viewz_sample;

        step_length *= 1.25;
        vpos_step += dir * step_length;
    }

    if (hit_iuv != ivec2(-1))
    {
        step_length *= -0.5;

        float viewz_sample;

        for (int i = 0; i < 4; i++)
        {
            vpos_sample += dir * step_length;

            vec3 proj_pos_sample = view2proj(vpos_sample);
            vec2 uv_sample = proj_pos_sample.st * 0.5 + 0.5;

            ivec2 iuv_sample = ivec2(uv_sample * vec2(viewWidth, viewHeight) * 0.5);
            hit_iuv = iuv_sample * 2;

            float depth_sample = texelFetch(colortex4, iuv_sample, 0).r;
            viewz_sample = proj2view(getProjPos(ivec2(iuv_sample), depth_sample)).z;

            if (viewz_sample > vpos_sample.z)
            {
                step_length *= 0.5;
            }
            else
            {
                step_length *= -0.5;
            }
        }

        if (abs(viewz_sample - vpos_sample.z) > abs(vpos_sample.z) * 0.1) hit_iuv = ivec2(-1);
    }

    return hit_iuv;

#endif

#ifdef SSR_2D
    float rayLength = clamp(-vpos.z, 0.1, 16.0);

    vec3 vpos_target = vpos + dir * rayLength;

    vec4 start_proj_pos = gbufferProjection * vec4(vpos, 1.0);
    vec4 target_proj_pos = gbufferProjection * vec4(vpos_target, 1.0);

    float k0 = 1.0 / start_proj_pos.w;
    float k1 = 1.0 / target_proj_pos.w;

    vec3 P0 = start_proj_pos.xyz * k0;
    vec3 P1 = target_proj_pos.xyz * k1;

    vec2 ZW = vec2(vpos.z * k0, k0);
    vec2 dZW = vec2(vpos_target.z * k1 - vpos.z * k0, k1 - k0);

    vec2 uv_dir = (P1.st - P0.st) * 0.5;
    uv_dir *= vec2(viewWidth, viewHeight);

    float invdx = 1.0;

    if (abs(uv_dir.x) > abs(uv_dir.y)) {
        invdx = 1.0 / abs(uv_dir.x);
        uv_dir = vec2(sign(uv_dir.x), uv_dir.y * invdx);
    } else {
        invdx = 1.0 / abs(uv_dir.y);
        uv_dir = vec2(uv_dir.x * invdx, sign(uv_dir.y));
    }

    float dither = getRand();

    uv_dir *= stride;
    dZW *= invdx * stride;

    ivec2 hit = ivec2(-1);

    float last_z = 0.0;

    iuv += uv_dir * 3.0;
    ZW += dZW * 3.0;

    float z_prev = (ZW.x + dZW.x * 0.5) / (ZW.y + dZW.y * 0.5);
    for (int i = 0; i < SSPT_SAMPLES; i++) {
        iuv += uv_dir;
        ZW += dZW;

        vec2 P1 = iuv - uv_dir * dither;
        vec2 ZWd = ZW - dZW * dither;

        if (P1.x < 0 || P1.y < 0 || P1.x > viewWidth || P1.y > viewHeight) return ivec2(-1);

        float z = (ZWd.x + dZW.x * 0.5) / (ZWd.y + dZW.y * 0.5);

        // if (-z > far * 0.9 || -z < near) break;
        if (-z < near) break;

        float zmin = z_prev, zmax = z;
        if (z_prev > z) {
            zmin = z;
            zmax = z_prev;
        }

        int dlod = clamp(int(floor(log2(length(uv_dir)) - 1.0)), 0, lod);

        float sampled_zbuffer = sampleLODmanual(colortex4, (P1 * invWidthHeight) * 0.5, dlod).r;
        float sampled_zmax = proj2view(getProjPos(ivec2(P1), sampled_zbuffer)).z;
        float sampled_zmin = sampled_zmax - zThickness;

        if (zmax > sampled_zmin && zmin < sampled_zmax && abs(abs(last_z - sampled_zmax) - abs(z - z_prev)) > 0.001) {
            hit = ivec2(P1);
            lod = dlod;
            break;
        }

        last_z = sampled_zmax;
        z_prev = z;

        uv_dir *= stride_multiplier;
        dZW *= stride_multiplier;
    }

    if (refine && hit != ivec2(-1))
    {
        iuv -= uv_dir * dither;
        ZW -= dZW * dither;
        for (int i = 0; i < 4; i++)
        {
            float z = ZW.x / ZW.y;

            int lod = clamp(int(floor(log2(length(uv_dir)) - 1.0)), 0, lod);

            hit = ivec2(iuv);

            vec2 uv = iuv * invWidthHeight;
            float sampled_zbuffer = sampleLODmanual(colortex4, uv * 0.5, lod).r;
            last_z = proj2view(getProjPos(uv, sampled_zbuffer)).z;
            z_prev = z;

            float z_next = (ZW.x + dZW.x * 1.0) / (ZW.y + dZW.y * 1.0);

            if ((last_z > z_prev && z_next < z_prev) || (last_z < z_prev && z_next > z_prev))
            {
                uv_dir *= -0.5;
                dZW *= -0.5;
            }
            else
            {
                uv_dir *= 0.5;
                dZW *= 0.5;
            }

            iuv += uv_dir;
            ZW += dZW;
        }
    }

    return hit;
#endif
}