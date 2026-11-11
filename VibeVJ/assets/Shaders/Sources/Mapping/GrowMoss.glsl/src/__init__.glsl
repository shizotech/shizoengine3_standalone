//@settings dtype=float32 format=rgba
// --- GrowMoss (#586, growing shapes for projection mapping) ---
// Moss, lichen or mould that spreads over the surfaces of a mask (or around the objects, or everywhere) from seeds:
// a stochastic front at half the size, two steps a frame (passes G1, G2), faster on fertile ground and along the
// outlines, and thicker where the ground is good. Each seed starts a colony with a colour of its own; the colonies
// meet in ragged borders. A soft, living texture: tufts, crusts with growth rings or fuzzy threads, slow breathing
// light, drifting spores. It never just fills up and stops: when it covers Turn at of its area (or after Turn every
// beats, or when it is stuck, or on Turn / a pulse) it turns (dries out from the old parts, burns, the gaps grow, it
// draws back into the seeds, new colonies take over: lib/growth.glsl). Pass S counts and keeps the cycle, pass O
// gives out life, turning, turn pulse and coverage (Values).
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D G2;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D S;
uniform sampler2D O;
uniform sampler2D T;

//@slider min=0.5 max=8.0 value=2.0
uniform float texture_size;   // the size of the tufts, crusts and threads, pixels
//@slider min=0.0 max=1.0 value=0.6
uniform float relief;         // light from the top left on the texture: 0 flat
//@slider min=0.0 max=1.0 value=0.35
uniform float colony_colors;  // how different the colours of the colonies are
//@slider min=0.0 max=1.0 value=0.4
uniform float breathing;      // slow waves of light through it
//@slider min=0.0 max=1.0 value=0.3
uniform float spores;         // little lights that drift up from it
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_glow;     // it lights up at a pulse (Pulse every, Trigger)
//@enum options=(Final, Thickness, Cells, Soil) value=0
uniform int debug_view;       // Thickness: thickness red, fertile ground green. Cells: generation and age. Soil: where it may grow

float tex_noise(vec2 p) {
    return mp_vnoise(p) * 0.55 + mp_vnoise(p * 2.13 + 5.2) * 0.3 + mp_vnoise(p * 4.37 + 1.7) * 0.15;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    gr_load(S);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 gres = vec2(textureSize(G2, 0));
    vec2 q = uv * gres;
    vec4 st = mp_bilinear(G2, q);
    vec4 look = mp_bilinear(C, q);
    vec4 near = texelFetch(G2, ivec2(clamp(q, vec2(0.0), gres - 1.0)), 0);
    float out_px = texelFetch(O, ivec2(0, 0), 0).a;

    if (debug_view == 1) {
        fragColor = vec4(st.x, st.y * 0.4, 0.0, 1.0);
        return;
    }
    if (debug_view == 2) {
        float g = near.z < 0.0 ? -1.0 : gr_cell_gen(near.z);
        vec3 c = g < 0.0 ? vec3(0.0) : mp_hue(g * 0.25 + near.w * 0.1) * (1.0 - 0.7 * look.x) * (1.0 - look.y);
        fragColor = vec4(c, 1.0);
        return;
    }
    if (debug_view == 3) {
        vec4 m = mp_bilinear_uv(M, uv);
        fragColor = vec4(m.r * 0.5, m.g, m.b * 0.3, 1.0);
        return;
    }

    float th = st.x;
    vec2 tp = fragCoord / max(texture_size, 0.5);
    float tex;
    if (style == 1) {
        // lichen: a crust with growth rings (the age of the front when it got here)
        float rings = 0.5 + 0.5 * cos(look.x * 46.0 + tex_noise(tp * 0.15) * 3.0);
        tex = 0.55 + 0.25 * rings + 0.2 * tex_noise(tp * 0.6);
    } else if (style == 2) {
        // mould: fuzzy threads in all directions
        float a1 = tex_noise(vec2(tp.x * 0.25, tp.y * 1.6));
        float a2 = tex_noise(vec2(tp.x * 1.6 + 9.0, tp.y * 0.25));
        tex = pow(max(a1, a2), 3.0) * 1.6 + 0.2;
    } else {
        // moss: soft tufts
        float n1 = tex_noise(tp * 0.5);
        float n2 = mp_vnoise(tp * 1.7 + 3.0);
        tex = 0.35 + 0.65 * smoothstep(0.2, 0.85, n1) * (0.7 + 0.3 * n2);
    }
    float height = th * tex;
    vec2 gh = vec2(dFdx(height), dFdy(height));
    vec3 n = normalize(vec3(-gh * 6.0 * relief, 1.0));
    vec3 ld = normalize(vec3(-0.5, 0.6, 0.65));
    float diff = max(dot(n, ld), 0.0);

    vec4 lk = look;
    lk.w = mix(0.5, lk.w, colony_colors * 2.0);
    vec3 col = gr_color(lk);
    float keep;
    vec3 emit;
    col = gr_dying(col, look.y, gr_turn_noise(uv * 3.0), keep, emit);

    float a = iResolution.x / max(iResolution.y, 1.0);
    float breathe = 1.0 + breathing * 0.25 * sin(iTime * 0.7 + tex_noise(vec2(uv.x * a, uv.y) * 3.0) * 7.0);
    float young = (1.0 - look.x) * (1.0 - look.x);
    float pulse = mp_pulse(T).x * pulse_glow;
    float cover = smoothstep(0.02, 0.18, th) * smoothstep(0.05, 0.35, tex) * keep;
    vec3 lit = col * (mix(1.0, 0.25 + 0.95 * diff, relief) * (0.55 + 0.6 * tex) * breathe + young * 0.25 + pulse * 0.5);
    if (style == 2) lit += col * pow(tex, 2.0) * 0.4;
    vec3 rgb = mix(background, lit, cover);
    rgb += col * glow * 0.25 * smoothstep(0.0, 0.5, th) * keep;
    rgb += emit * smoothstep(0.02, 0.2, th);

    // spores: a few lights in each cell of 40 px that rise from covered places
    if (spores > 0.0) {
        vec2 cp = fragCoord / 40.0;
        ivec2 ci = ivec2(floor(cp));
        for (int j = 0; j < 2; j++) {
            ivec2 cj = ci - ivec2(0, j);
            float r = mp_rand3(ivec3(cj, 1));
            if (r > spores * 0.6) continue;
            float life = fract(iTime * 0.08 * (0.6 + r) + mp_rand3(ivec3(cj, 2)));
            vec2 base = (vec2(cj) + vec2(mp_rand3(ivec3(cj, 3)), mp_rand3(ivec3(cj, 4)))) * 40.0;
            vec2 sp = base + vec2(sin(life * 6.0 + r * 20.0) * 6.0, life * 60.0);
            float under = mp_bilinear_uv(G2, base / iResolution.xy).x;
            float dd = length(fragCoord - sp);
            rgb += (col + 0.3) * under * exp(-dd * dd / 3.0) * sin(life * MP_PI) * 1.2;
        }
    }
    if (out_px > 2.0) rgb = vec3(1.0);   // reads O so that it renders every frame (the values)
    fragColor = gr_finish(rgb, cover, uv);
}
