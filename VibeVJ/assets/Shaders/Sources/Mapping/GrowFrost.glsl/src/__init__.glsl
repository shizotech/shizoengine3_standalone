//@settings dtype=float32 format=rgba
// --- GrowFrost (#586, growing shapes for projection mapping) ---
// Frost and ice crystals that grow from seeds and along the outlines of a mask: Kobayashi's phase field of freezing
// (an anisotropic interface that grows into undercooled water and gives off heat) at half the size, six steps a frame
// (passes F1..F6). Each crystal keeps its own axis, so neighbours point different ways; 6 arms make snow, 4 square
// crystals, 2 needles. It never just fills up and stops: when it covers Turn at of its area (or after Turn every
// beats, or when it is stuck, or on Turn / a pulse) it turns (thaws, burns, the gaps freeze, it melts back into the
// seeds, new crystals take over: lib/growth.glsl) and a new generation grows. Pass S counts and keeps the cycle,
// pass O gives out life, turning, turn pulse and coverage (Values).
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D F6;
uniform sampler2D C;
uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D S;
uniform sampler2D O;
uniform sampler2D T;

//@slider min=0.0 max=1.0 value=0.7
uniform float ice_opacity;    // how much the ice covers what is behind it
//@slider min=0.0 max=2.0 value=1.0
uniform float rim;            // the bright edges of the crystals
//@slider min=0.0 max=2.0 value=0.8
uniform float sparkle;        // glints that twinkle on the ice
//@slider min=0.0 max=1.0 value=0.08
uniform float heat_glow;      // the heat the freezing gave off, as a faint glow
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_glow;     // the ice lights up at a pulse (Pulse every, Trigger)
//@enum options=(Final, Phase and heat, Cells, Soil) value=0
uniform int debug_view;       // Phase and heat: ice blue, heat red. Cells: generation and age. Soil: where it may grow

float p_at(vec2 q) { return mp_bilinear(F6, q).x; }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    gr_load(S);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 fres = vec2(textureSize(F6, 0));
    vec2 q = uv * fres;
    vec4 st = mp_bilinear(F6, q);
    vec4 look = mp_bilinear(C, q);
    vec4 near = texelFetch(F6, ivec2(clamp(q, vec2(0.0), fres - 1.0)), 0);
    float out_px = texelFetch(O, ivec2(0, 0), 0).a;

    if (debug_view == 1) {
        fragColor = vec4(st.y, st.x * 0.5, st.x, 1.0);
        return;
    }
    if (debug_view == 2) {
        float g = near.z < 0.0 ? -1.0 : gr_cell_gen(near.z);
        vec3 c = g < 0.0 ? vec3(0.0) : mp_hue(g * 0.25) * (1.0 - 0.7 * look.x) * (1.0 - look.y);
        fragColor = vec4(c * (0.3 + 0.7 * fract(near.w * 0.15915)), 1.0);
        return;
    }
    if (debug_view == 3) {
        vec4 m = mp_bilinear_uv(M, uv);
        fragColor = vec4(m.r * 0.5, m.g, m.b * 0.3, 1.0);
        return;
    }

    float ph = st.x;
    float ice = smoothstep(0.3, 0.7, ph);
    vec2 g = vec2(p_at(q + vec2(1.0, 0.0)) - p_at(q - vec2(1.0, 0.0)), p_at(q + vec2(0.0, 1.0)) - p_at(q - vec2(0.0, 1.0)));
    vec3 n = normalize(vec3(-g * 2.5, 1.0));
    vec3 ld = normalize(vec3(-0.45, 0.6, 0.65));
    float diff = max(dot(n, ld), 0.0);
    float spec = pow(max(dot(reflect(-ld, n), vec3(0.0, 0.0, 1.0)), 0.0), 30.0);
    float edge = clamp(length(g) * 1.6, 0.0, 1.0);

    vec3 col = gr_color(look);
    float keep;
    vec3 emit;
    col = gr_dying(col, look.y, gr_turn_noise(uv * 3.0), keep, emit);

    // glints: a few texels of the ice light up for a moment
    ivec2 cellq = ivec2(fragCoord / 3.0);
    float tw = floor(iTime * 6.0 + mp_rand2(cellq) * 6.0);
    float glint = step(0.993, mp_rand3(ivec3(cellq, int(tw)))) * ice * keep;

    float pulse = mp_pulse(T).x * pulse_glow;
    float young = (1.0 - look.x) * (1.0 - look.x);
    vec3 body = col * (0.45 + 0.55 * diff + young * 0.3 + pulse * 0.5);
    vec3 rgb = background;
    rgb += gr_palette(palette, 0.2) * clamp(st.y, 0.0, 1.0) * heat_glow * (1.0 - ice);
    rgb = mix(rgb, body, ice * keep * ice_opacity);
    rgb += (col * 0.6 + 0.4) * edge * rim * 0.6 * keep;
    rgb += vec3(spec) * 0.5 * ice * keep;
    rgb += col * glow * 0.3 * smoothstep(0.05, 0.6, ph) * keep;
    rgb += vec3(1.0) * glint * sparkle;
    rgb += emit * max(ice, 0.3 * smoothstep(0.05, 0.4, ph));
    if (out_px > 2.0) rgb = vec3(1.0);   // reads O so that it renders every frame (the values)
    fragColor = gr_finish(rgb, max(ice * keep * ice_opacity, edge * keep), uv);
}
