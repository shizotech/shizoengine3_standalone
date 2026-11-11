//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskRipples, pass W: the water surface at half size, one step of the wave equation a frame (9-point Laplacian,
// leapfrog). r: height now, g: height a frame ago, b: brightness of the picture (for Motion) ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D M;
uniform sampler2D T;
uniform sampler2D I;          // is a picture linked (pass I): not textureSize() here, this pass has other inputs (#880)

bool rp_is_water(ivec2 q, ivec2 size) {
    if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y) return false;
    return rp_water_of(texelFetch(M, q, 0).r) > 0.5;
}

// A smooth bump of radius r (texels) around c, 0 outside
float rp_bump(vec2 p, vec2 c, float r) {
    float d = length(p - c) / max(r, 0.5);
    return d < 1.0 ? 0.5 + 0.5 * cos(d * MP_PI) : 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    ivec2 size = ivec2(iResolution.xy);
    vec2 uv = fragCoord / iResolution.xy;
    bool linked = texelFetch(I, ivec2(0, 0), 0).r > 0.5;
    float lum = linked ? rp_luma(texture(picture, uv).rgb) : 0.0;
    if (iFrame < 2 || textureSize(feedback, 0) != size) {
        fragColor = vec4(0.0, 0.0, lum, 0.0);
        return;
    }
    vec4 c = texelFetch(feedback, p, 0);
    if (!rp_is_water(p, size)) {
        fragColor = vec4(0.0, 0.0, lum, 0.0);
        return;
    }
    float h = c.r;
    float hp = c.g;

    // the neighbours; at the shore Reflect takes the own height (no flow through it), Fixed 0
    float sum4 = 0.0;
    float sumd = 0.0;
    bool near_shore = false;
    for (int k = 0; k < 8; k++) {
        ivec2 o = k == 0 ? ivec2(1, 0) : k == 1 ? ivec2(-1, 0) : k == 2 ? ivec2(0, 1) : k == 3 ? ivec2(0, -1)
                : k == 4 ? ivec2(1, 1) : k == 5 ? ivec2(-1, 1) : k == 6 ? ivec2(1, -1) : ivec2(-1, -1);
        ivec2 q = p + o;
        float v;
        if (rp_is_water(q, size)) v = texelFetch(feedback, q, 0).r;
        else {
            near_shore = true;
            v = shore == 1 ? 0.0 : h;
        }
        if (k < 4) sum4 += v;
        else sumd += v;
    }
    float lap = (4.0 * sum4 + sumd - 20.0 * h) / 6.0;
    float c2 = 0.5 * wave_speed * wave_speed;
    float damp = damping + (shore == 2 && near_shore ? 0.25 : 0.0);
    float hn = h + (h - hp) * (1.0 - damp) + c2 * lap;

    // rain: up to four drops a frame, each somewhere in the picture
    vec2 pos = fragCoord;
    float r_drop = drop_size * PASS_SCALE;
    vec3 pl = mp_pulse(T);
    float rate = rain * (pulse_action == 2 ? 1.0 + 8.0 * pl.x : 1.0);
    uint fr = uint(iFrame);
    for (int k = 0; k < 4; k++) {
        uint s = fr * 8u + uint(k);
        if (mp_rand(s * 3u + 1u) >= rate * 0.25) continue;
        vec2 dc = vec2(mp_rand(s * 3u + 2u), mp_rand(s * 3u + 3u)) * iResolution.xy;
        float rr = r_drop * (0.6 + 0.8 * mp_rand(s * 5u + 7u));
        hn -= drop_strength * rp_bump(pos, dc, rr);
    }

    // the pulse
    if (pl.z > 0.5 && pulse_action == 0) {
        // a big drop: the first of four random places that is in the water
        int ki = int(pl.y);
        for (int k = 0; k < 4; k++) {
            vec2 dc = vec2(0.1 + 0.8 * mp_rand3(ivec3(ki, k, 3)), 0.1 + 0.8 * mp_rand3(ivec3(ki, k, 4))) * iResolution.xy;
            if (!rp_is_water(ivec2(dc), size)) continue;
            hn -= pulse_strength * 1.5 * rp_bump(pos, dc, r_drop * 3.0);
            break;
        }
    }
    if (pl.z > 0.5 && pulse_action == 1 && near_shore) hn -= pulse_strength;

    // the picture
    if (linked && picture_stir == 1) hn -= stir_amount * 2.0 * (lum - c.b);
    if (linked && picture_stir == 2) hn -= stir_amount * 0.03 * lum;

    // the wind: a noise that drifts and changes stirs small waves everywhere
    if (wind > 0.0) {
        vec2 q = fragCoord / max(wind_scale * PASS_SCALE, 1.0);
        float t = float(iFrame) * 0.05;
        float a = mp_vnoise(q + vec2(t, t * 0.7)) - mp_vnoise(q + vec2(t - 0.05, (t - 0.05) * 0.7));
        float b = mp_vnoise(q * 1.7 + vec2(-t * 0.8, 9.0)) - mp_vnoise(q * 1.7 + vec2(-(t - 0.05) * 0.8, 9.0));
        hn += wind * 0.12 * (a + 0.6 * b);
    }

    // the swimmers: a wake behind each
    for (int i = 0; i < 6; i++) {
        if (i >= swimmers) break;
        vec2 sc = rp_swimmer(i, iTime) * iResolution.xy;
        hn -= 0.12 * drop_strength * rp_bump(pos, sc, r_drop * 1.2);
    }

    if (isnan(hn) || isinf(hn)) hn = 0.0;
    hn = clamp(hn, -6.0, 6.0);
    fragColor = vec4(hn, h, lum, 0.0);
}
