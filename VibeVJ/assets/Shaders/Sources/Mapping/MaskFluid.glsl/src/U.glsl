//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFluid, pass U: the velocity of the last frame (Q) carried along by itself, plus the forces: swirls
// (vorticity confinement), buoyancy of the smoke, wind, the jets, the push of the outlines and of the picture, the
// burst of a pulse. Velocities are in texels of this grid per frame ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D Q;
uniform sampler2D M;
uniform sampler2D T;
uniform sampler2D Y;

float curl_at(ivec2 q) {
    return 0.5 * ((fl_fetch(Q, q + ivec2(1, 0)).y - fl_fetch(Q, q - ivec2(1, 0)).y)
                - (fl_fetch(Q, q + ivec2(0, 1)).x - fl_fetch(Q, q - ivec2(0, 1)).x));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    vec4 mm = texelFetch(M, p, 0);
    if (mm.r > 0.5 || iFrame < 2) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    float dt = sim_speed;
    vec2 uv = fragCoord / iResolution.xy;

    // carried along by itself
    vec2 v0 = texelFetch(Q, p, 0).xy;
    vec2 v = mp_bilinear(Q, fragCoord - v0 * dt).xy;

    // vorticity confinement: pushes along the swirls so they stay
    float c = curl_at(p);
    vec2 grad = vec2(abs(curl_at(p + ivec2(1, 0))) - abs(curl_at(p - ivec2(1, 0))),
                     abs(curl_at(p + ivec2(0, 1))) - abs(curl_at(p - ivec2(0, 1))));
    float gl = length(grad);
    if (gl > 1e-5) v += vorticity * dt * 0.6 * vec2(grad.y, -grad.x) / gl * c;

    // smoke rises, wind
    float dens = mp_bilinear_uv(Y, uv).a;
    v.y += buoyancy * dt * 0.05 * min(dens, 3.0);
    v += wind * dt * 0.03;

    // the jets
    float r = max(emitter_size * PASS_SCALE, 1.0);
    if (emitter_layout != 4) {
        for (int i = 0; i < 8; i++) {
            if (i >= emitter_count) break;
            vec2 pos;
            vec2 dir;
            fl_emitter(i, pos, dir);
            vec2 dd = (uv - pos) * iResolution.xy;
            v += dir * jet_strength * dt * 0.35 * exp(-dot(dd, dd) / (r * r));
        }
    }

    // the outlines push the flow away, the picture pushes up where it is bright
    v += mm.gb * edge_push * mm.a * dt * 0.3;
    if (picture_push > 0.0) {
        vec3 pc = texture(emit_picture, uv).rgb;
        v.y += picture_push * max(pc.r, max(pc.g, pc.b)) * dt * 0.08;
    }

    // a pulse: a burst
    vec3 pl = mp_pulse(T);
    if (pl.z > 0.5 && burst_amount > 0.0) {
        if (burst_mode == 0) {
            vec2 dd = (uv - fl_burst_pos(pl.y)) * iResolution.xy;
            float rb = r * 2.5;
            float l = length(dd);
            if (l > 0.01) v += dd / l * burst_amount * 3.0 * exp(-l * l / (rb * rb));
        } else if (burst_mode == 1) {
            for (int i = 0; i < 8; i++) {
                if (i >= emitter_count) break;
                vec2 pos;
                vec2 dir;
                fl_emitter(i, pos, dir);
                vec2 dd = (uv - pos) * iResolution.xy;
                v += dir * burst_amount * 4.0 * exp(-dot(dd, dd) / (r * r * 4.0));
            }
        } else {
            v += mm.gb * mm.a * burst_amount * 3.0;
        }
    }

    v *= 1.0 - velocity_fade;
    v = fl_walls(M, p, v);
    float sp = length(v);
    if (sp > 6.0) v *= 6.0 / sp;
    fragColor = vec4(v, 0.0, 1.0);
}
