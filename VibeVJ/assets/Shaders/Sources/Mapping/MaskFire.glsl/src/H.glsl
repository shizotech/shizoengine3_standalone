//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskFire, pass H: heat (r) and smoke (g) at half size, carried by the flow of lib/common.glsl (semi-Lagrangian),
// cooled with a noise that rises with the flames (the tongues), fed by the sources ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D M;
uniform sampler2D T;
uniform sampler2D I;          // is a picture linked (pass I): not textureSize() here, this pass has other inputs (#880)

// How much texel pos (texels of this pass) is a source of fire
float fr_source(vec2 pos, vec3 pl) {
    vec2 res = iResolution.xy;
    vec2 uv = pos / res;
    float t = fr_time();
    float src = 0.0;
    float w = source_width * PASS_SCALE;    // texels
    float here = fr_source_solid(texelFetch(M, ivec2(pos), 0).r);
    if (fire_source == 0 || fire_source == 1) {
        if (here < 0.5) {
            // free texel: is there a surface below it (Top edges) or anywhere near it (All outlines)?
            float near = 0.0;
            for (int k = 1; k <= 3; k++) {
                float dd = w * float(k) / 3.0;
                if (fire_source == 0) {
                    // the bottom of the picture is ground in a container (a door) and without a mask
                    bool ground = mask_role == 1 || mp_mask_mode() == 4;
                    near = max(near, pos.y - dd < 0.0 ? (ground ? 1.0 : 0.0) : fr_source_solid(mp_bilinear(M, pos - vec2(0.0, dd)).r));
                } else {
                    for (int a = 0; a < 6; a++) {
                        float an = float(a) * (MP_TAU / 6.0) + float(k);
                        near = max(near, fr_source_solid(mp_bilinear(M, pos + vec2(cos(an), sin(an)) * dd).r));
                    }
                }
            }
            src = near;
        }
    } else if (fire_source == 2) {
        src = here;
    } else if (fire_source == 3) {
        src = 1.0 - smoothstep(w * 0.5, w, pos.y);
    }
    // patchy, flickering fuel
    float flick = 0.45 + 0.9 * mp_vnoise(pos * 0.12 + vec2(0.0, -t * 3.0)) * mp_vnoise(pos * 0.05 + vec2(t * 0.7, 3.0));
    float f = fuel;
    if (pulse_action == 0 || pulse_action == 2) f *= 1.0 + pulse_amount * pl.x;
    float geo = src;
    src *= f * flick;
    if (pulse_action == 3) src = max(src, geo * pulse_amount * pl.x * 1.5);
    bool linked = texelFetch(I, ivec2(0, 0), 0).r > 0.5;
    if (linked && picture_fuel > 0.0) src += picture_fuel * fr_luma(texture(emit_picture, uv).rgb) * (0.6 + 0.6 * flick);
    return src;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    vec2 uv = fragCoord / iResolution.xy;
    if (iFrame < 2 || textureSize(feedback, 0) != ivec2(iResolution.xy)) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 pl = mp_pulse(T);
    float wall = fr_wall_of(texelFetch(M, p, 0).r);
    if (wall > 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 v = fr_velocity(M, uv) * PASS_SCALE;          // texels a frame
    vec4 prev = mp_bilinear(feedback, fragCoord - v);
    // a little spreading, so the flames stay soft
    vec4 nb = texelFetch(feedback, p + ivec2(1, 0), 0) + texelFetch(feedback, p - ivec2(1, 0), 0)
            + texelFetch(feedback, p + ivec2(0, 1), 0) + texelFetch(feedback, p - ivec2(0, 1), 0);
    prev = mix(prev, nb * 0.25, 0.08);

    float t = fr_time();
    // the cooling rises with the flames and breaks them into tongues
    vec2 cq = fragCoord / iResolution.y * 14.0 * turbulence_scale / 3.0 - vec2(0.0, t * 2.2 * rise);
    float cn = mp_vnoise(cq) * 0.7 + mp_vnoise(cq * 2.1 + 7.0) * 0.3;
    float heat = prev.r - cooling * (0.25 + 2.4 * cn * cn) - 0.002;
    float sm = prev.g * 0.985 + max(prev.r, 0.0) * cooling * 0.6;

    heat = max(heat, fr_source(fragCoord, pl));
    heat = clamp(heat, 0.0, 2.0);
    sm = clamp(sm, 0.0, 2.0);
    if (isnan(heat) || isnan(sm)) {
        heat = 0.0;
        sm = 0.0;
    }
    fragColor = vec4(heat, sm, 0.0, 1.0);
}
