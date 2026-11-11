//@settings dtype=float32 format=rgba
// --- GrowBranches (#586, growing shapes for projection mapping) ---
// Branches, roots, vines or veins that grow from seeds over the surfaces of a mask (or around the objects, or
// everywhere): tips at half the size, two steps a frame (passes B1, B2), that meander, climb up or hang down like
// roots, feel ahead and turn away from other branches and walls, run along the outlines and split; the wood gets
// thicker with age, light runs through it from the roots to the tips. The branches are drawn from a jump flood of
// the wood (passes E, J1..J10). It never just fills up and stops: when the area near the branches covers Turn at (or
// after Turn every beats, or when no tip grows any more, or on Turn / a pulse) it turns (dies from the roots, burns
// along the branches like a fuse, new shoots grow out of the old wood, draws back into the seeds, new seeds take
// over: lib/growth.glsl). Pass S counts and keeps the cycle, pass O gives out life, turning, turn pulse and coverage
// (Values).
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D J10;
uniform sampler2D B2;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D S;
uniform sampler2D O;
uniform sampler2D T;

//@slider min=0.0 max=2.0 value=0.8
uniform float sap_flow;       // light that runs along the branches, from the roots to the tips
//@slider min=0.0 max=4.0 value=1.0
uniform float sap_speed;      // how fast it runs
//@slider min=10.0 max=400.0 value=90.0
uniform float sap_spacing;    // pixels along a branch between two lights
//@slider min=0.0 max=2.0 value=1.0
uniform float bud_glow;       // the growing tips glow
//@slider min=0.0 max=1.0 value=0.6
uniform float roundness;      // the branches are lit like tubes: 0 flat
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_glow;     // the branches light up at a pulse (Pulse every, Trigger)
//@enum options=(Final, Tips and wood, Distance, Soil) value=0
uniform int debug_view;       // Tips and wood: tips white, wood by order. Distance: to the nearest branch. Soil: where it may grow

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    gr_load(S);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 jres = vec2(textureSize(J10, 0));
    vec2 q = uv * jres;
    float out_px = texelFetch(O, ivec2(0, 0), 0).a;

    if (debug_view == 1) {
        vec4 b = texelFetch(B2, ivec2(q), 0);
        vec3 c = b.x > 1.5 ? vec3(1.0) : (b.x > 0.5 ? mp_hue(br_order(b) * 0.08) * (0.4 + 0.6 * fract(br_path(b) / 64.0)) : vec3(0.0));
        fragColor = vec4(c, 1.0);
        return;
    }
    if (debug_view == 3) {
        vec4 m = mp_bilinear_uv(M, uv);
        fragColor = vec4(m.r * 0.5, m.g, m.b * 0.3, 1.0);
        return;
    }

    // the branch that covers this pixel most among the nearest seeds of the 3 x 3 texels of the flood
    ivec2 ci = ivec2(floor(q));
    ivec2 hi = ivec2(jres) - 1;
    vec4 best = vec4(0.0);
    float best_score = -1e9;
    float best_d = 1e9;
    float nearest = 1e9;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec4 v = texelFetch(J10, clamp(ci + ivec2(x, y), ivec2(0), hi), 0);
            if (v.w < 0.5) continue;
            float d = length(v.xy - q);
            nearest = min(nearest, d);
            float score = v.z - d;
            if (score > best_score) { best_score = score; best = v; best_d = d; }
        }
    }
    if (debug_view == 2) {
        float dpx = nearest * 2.0;
        fragColor = vec4(vec3(fract(dpx / 20.0)) * exp(-dpx / 200.0), 1.0);
        return;
    }

    vec3 rgb = background;
    float cover = 0.0;
    if (best.w > 0.5) {
        ivec2 st = ivec2(best.xy);
        vec4 b = texelFetch(B2, st, 0);
        vec4 look = texelFetch(C, st, 0);
        float r = best.z;
        float aa = 0.6;
        float line = smoothstep(r + aa, r - aa, best_d);
        vec3 col = gr_color(look);
        float keep;
        vec3 emit;
        col = gr_dying(col, look.y, gr_turn_noise(uv * 4.0), keep, emit);
        // a tube, lit from the top left
        float xr = clamp(best_d / max(r, 0.3), 0.0, 1.0);
        float tube = mix(1.0, sqrt(1.0 - xr * xr) * 0.75 + 0.25, roundness);
        // light running through it, from the seed out to the tips (the length of the path from the seed)
        float path = br_path(b) * 2.0;
        float sap = pow(max(cos((path / max(sap_spacing, 1.0) - iTime * sap_speed) * MP_TAU), 0.0), 10.0) * sap_flow;
        float pulse = mp_pulse(T).x * pulse_glow;
        vec3 wood = col * (tube * (0.7 + pulse * 0.6)) + col * sap * 1.2;
        cover = line * keep;
        rgb = mix(rgb, wood, cover);
        // a soft halo, and the buds at the tips
        float halo = exp(-max(best_d - r, 0.0) / 2.5) * (1.0 - line);
        rgb += col * glow * 0.4 * halo * keep;
        if (best.w > 1.5 && bud_glow > 0.0) {
            float bud = exp(-best_d * best_d / max(r * r * 4.0, 1.0));
            rgb += mix(col, vec3(1.0), 0.5) * bud * bud_glow * keep;
        }
        rgb += emit * 0.6 * max(line, halo * 0.4);
    }
    if (out_px > 2.0) rgb = vec3(1.0);   // reads O so that it renders every frame (the values)
    fragColor = gr_finish(rgb, cover, uv);
}
