//@settings dtype=float32 format=rgba
// --- GrowCoral (#586, growing shapes for projection mapping) ---
// Coral, mazes, fingerprints, spots or worms that grow out of seeds over the surfaces of a mask (or around the
// objects, or everywhere): a Gray-Scott reaction and diffusion at half the size, six steps a frame (passes R1..R6),
// with fronts that spread from the seed points, the outlines of the mask, a picture and the pulses of the beat.
// It never just fills up and stops: when it covers Turn at of its area (or after Turn every beats, or when it is
// stuck, or on Turn / a pulse) it turns (Wither, Burn, Invert, Recede, Reseed, lib/growth.glsl) and a new generation
// grows. Pass S counts and keeps the cycle, pass O gives out life, turning, turn pulse and coverage (Values).
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D R6;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D S;
uniform sampler2D O;
uniform sampler2D T;

//@slider min=0.0 max=1.0 value=0.6
uniform float relief;         // light from the top left on the shapes: 0 flat
//@slider min=0.0 max=1.0 value=0.25
uniform float fill_between;   // the colour also between the lines of the pattern (the area it has reached)
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_glow;     // the shapes light up at a pulse (Pulse every, Trigger)
//@enum options=(Final, Chemicals, Cells, Soil) value=0
uniform int debug_view;       // Chemicals: U red, V green. Cells: generation and age. Soil: where it may grow and the outlines

float v_at(vec2 q) { return mp_bilinear(R6, q).y; }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    gr_load(S);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 rres = vec2(textureSize(R6, 0));
    vec2 q = uv * rres;
    vec4 st = mp_bilinear(R6, q);
    vec4 look = mp_bilinear(C, q);
    vec4 near = texelFetch(R6, ivec2(clamp(q, vec2(0.0), rres - 1.0)), 0);
    float out_px = texelFetch(O, ivec2(0, 0), 0).a;

    if (debug_view == 1) {
        fragColor = vec4(st.x, st.y * 2.0, 0.0, 1.0);
        return;
    }
    if (debug_view == 2) {
        float g = near.z < 0.0 ? -1.0 : gr_cell_gen(near.z);
        vec3 c = g < 0.0 ? vec3(0.0) : mp_hue(g * 0.25) * (1.0 - 0.7 * look.x) * (1.0 - look.y);
        fragColor = vec4(c, 1.0);
        return;
    }
    if (debug_view == 3) {
        vec4 m = mp_bilinear_uv(M, uv);
        fragColor = vec4(m.r * 0.5, m.g, m.b * 0.3, 1.0);
        return;
    }

    // the shapes: V as a height, lit
    float v = st.y;
    float h = smoothstep(0.1 + look.y * 0.25, 0.36 + look.y * 0.25, v);   // dying shapes get thinner
    float dx = v_at(q + vec2(1.0, 0.0)) - v_at(q - vec2(1.0, 0.0));
    float dy = v_at(q + vec2(0.0, 1.0)) - v_at(q - vec2(0.0, 1.0));
    vec3 n = normalize(vec3(-dx * 6.0 * relief, -dy * 6.0 * relief, 1.0));
    vec3 ld = normalize(vec3(-0.5, 0.6, 0.65));
    float diff = max(dot(n, ld), 0.0);
    float spec = pow(max(dot(reflect(-ld, n), vec3(0.0, 0.0, 1.0)), 0.0), 24.0) * relief;

    // the area the cells have reached (bilinear, so its edge is smooth)
    vec2 qf = q - 0.5;
    ivec2 qi = ivec2(floor(qf));
    vec2 fr = fract(qf);
    ivec2 hi = ivec2(rres) - 1;
    float r00 = step(0.0, texelFetch(R6, clamp(qi, ivec2(0), hi), 0).z);
    float r10 = step(0.0, texelFetch(R6, clamp(qi + ivec2(1, 0), ivec2(0), hi), 0).z);
    float r01 = step(0.0, texelFetch(R6, clamp(qi + ivec2(0, 1), ivec2(0), hi), 0).z);
    float r11 = step(0.0, texelFetch(R6, clamp(qi + ivec2(1, 1), ivec2(0), hi), 0).z);
    float reached = smoothstep(0.25, 0.75, mix(mix(r00, r10, fr.x), mix(r01, r11, fr.x), fr.y));
    vec3 col = gr_color(look);
    float keep;
    vec3 emit;
    col = gr_dying(col, look.y, gr_turn_noise(uv * 3.0), keep, emit);

    // the youngest parts (the growing front) are brighter
    float young = (1.0 - look.x) * (1.0 - look.x);
    float pulse = mp_pulse(T).x * pulse_glow;
    vec3 lit = col * (mix(1.0, 0.3 + 0.85 * diff, relief) + young * 0.35 + pulse * 0.5) + vec3(spec * 0.35);
    float cover = h * keep;
    float between = fill_between * reached * keep * (1.0 - h);
    vec3 rgb = background;
    rgb = mix(rgb, col * 0.35, between);
    rgb = mix(rgb, lit, cover);
    rgb += col * glow * 0.35 * smoothstep(0.05, 0.3, v) * keep;
    rgb += emit * max(h, 0.35 * reached);
    if (out_px > 2.0) rgb = vec3(1.0);   // reads O so that it renders every frame (the values)
    fragColor = gr_finish(rgb, max(cover, between), uv);
}
