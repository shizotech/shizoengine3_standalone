//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskFluid, pass Y: the smoke (half size, finer than the flow). rgb: colour times density, a: density.
// Carried along by the velocity of Q, it fades, it is kept out of the walls, the jets, the outlines, the picture
// and the bursts add to it ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D Q;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float scale = iResolution.x / float(textureSize(Q, 0).x);
    vec2 vel = mp_bilinear_uv(Q, uv).xy * scale;
    vec4 dye = mp_bilinear(feedback, fragCoord - vel * sim_speed) * (1.0 - dye_fade);
    if (iFrame < 2) dye = vec4(0.0);

    vec4 mm = mp_bilinear_uv(M, uv);
    dye *= 1.0 - smoothstep(0.35, 0.65, mm.r);

    float r = max(emitter_size * PASS_SCALE, 1.0);
    if (emitter_layout != 4 && dye_amount > 0.0) {
        for (int i = 0; i < 8; i++) {
            if (i >= emitter_count) break;
            vec2 pos;
            vec2 dir;
            fl_emitter(i, pos, dir);
            vec2 dd = (uv - pos) * iResolution.xy;
            float w = exp(-dot(dd, dd) / (r * r)) * dye_amount * 0.12;
            dye += vec4(fl_emitter_color(i) * w, w);
        }
    }
    if (edge_emit > 0.0) {
        float w = mm.a * edge_emit * 0.06 * (1.0 - smoothstep(0.35, 0.65, mm.r));
        dye += vec4(edge_color * w, w);
    }
    if (picture_emit > 0.0) {
        vec3 pc = texture(emit_picture, uv).rgb;
        float l = max(pc.r, max(pc.g, pc.b));
        float w = l * picture_emit * 0.05;
        dye += vec4(pc / max(l, 0.05) * w, w);
    }
    vec3 pl = mp_pulse(T);
    if (pl.z > 0.5 && burst_amount > 0.0) {
        vec3 bc = color_mode == 1 ? mp_hue(fract(pl.y * 0.37)) : (mod(pl.y, 2.0) < 1.0 ? color_a : color_b);
        float w = 0.0;
        if (burst_mode == 0) {
            // a ring of smoke with a ragged edge, which the burst of U blows outwards
            vec2 dd = (uv - fl_burst_pos(pl.y)) * iResolution.xy;
            float rb = r * 2.0;
            float l = length(dd);
            float ring = (l - rb * 0.6) / (rb * 0.3);
            w = exp(-ring * ring) * (0.4 + mp_vnoise(dd / max(rb * 0.25, 1.0) + pl.y * 3.1));
        } else if (burst_mode == 1) {
            for (int i = 0; i < 8; i++) {
                if (i >= emitter_count) break;
                vec2 pos;
                vec2 dir;
                fl_emitter(i, pos, dir);
                vec2 dd = (uv - pos) * iResolution.xy;
                w += exp(-dot(dd, dd) / (r * r * 4.0));
            }
        } else {
            w = mm.a;
        }
        w *= burst_amount * 0.5;
        dye += vec4(bc * w, w);
    }
    fragColor = min(dye, vec4(6.0));
}
