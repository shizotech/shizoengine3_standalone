// ---- Growing shapes (#586, sixth set): the life cycle, the seeds and the colours every growing asset shares ----
// The same file is in src/lib/ of each of them. Include mapping.glsl, mask.glsl and beat.glsl before it, and declare
// the two controls whose default differs per asset before it as well: `uniform int cycle_mode;` (Wither, Burn,
// Invert, Recede, Reseed) and `uniform int palette;` (the options of gr_palette).
//
// The cycle: a generation grows until it covers Turn at of its area (or after Turn every beats, or when it has not
// grown for Turn when stuck beats, or on Turn / a pulse). Then it turns for Turn length beats: Wither (dies from its
// oldest parts on), Burn (a fire runs through it along the way it grew), Invert (the next generation grows in the gaps,
// the old one fades), Recede (dies back into its seeds) or Reseed (a new generation from new places takes over). The
// next generation starts at a point of the turn that depends on the mode, so the picture is never empty for long.
//
// Pass S (rendersize=(4,1)) keeps the state, every pass reads it with gr_load(S):
//   pixel 0: clock (beats since the last turn began), phase (0 growing, 1 turning), beats into the turn, generation
//   pixel 1: frames left to plant the seeds, best coverage, clock of the best, clock when the turn began
//   pixel 2: iTime of the last frame, frames since it last grew * 2 + Turn of the last frame, the new generation could
//            grow, clock when growth began
//   pixel 3: life (coverage / Turn at), turning (0..1), turn pulse, coverage: what pass O gives out (//@readout)
// A cell keeps its generation and its birth (clock) packed in one float: gr_pack(gen, birth), -1 = empty.
// (Not named `packed` in the code: Mesa reserves the word, glslang does not complain.)

// The colour a withering cell dries to; an asset can #define its own before it includes this file
#ifndef GR_DRY
#define GR_DRY vec3(0.42, 0.31, 0.18)
#endif

uniform sampler2D seed_picture;   // optional: seeds where this picture is bright (a video, a camera, a shader)

// Is a picture linked into Seed picture? Asked in pass I (one pixel, no other input) and not in the pass that plants
// the seeds: that one has other inputs, and an unlinked sampler there reads one of them (lib/mask.glsl, #880)
bool gr_seed_picture_linked = false;
vec4 gr_seed_picture_pass() { return vec4(textureSize(seed_picture, 0).x > 1 ? 1.0 : 0.0, 0.0, 0.0, 1.0); }
void gr_seed_picture_from(sampler2D i) { gr_seed_picture_linked = texelFetch(i, ivec2(0, 0), 0).r > 0.5; }

//@enum options=(On the surfaces, Around the objects, Everywhere) value=0
uniform int mask_role;        // where it grows: on the white of the mask, in the free space around it, or everywhere
//@slider min=0.1 max=1.0 value=0.75
uniform float turn_at;        // the share of its area grown when it turns (1: only by Turn every, when stuck or by hand)
//@int min=0 max=512 value=0
uniform int turn_every;       // beats: it turns after this many beats anyway; 0 off
//@int min=0 max=128 value=24
uniform int turn_when_stuck;  // beats without growth before it turns; 0 never
//@slider min=0.5 max=64.0 value=8.0
uniform float turn_length;    // beats the turn takes
//@button
uniform bool turn;            // turns now: map it to a MIDI note or a pad
//@enum options=(Nothing, Seed burst, Turn) value=0
uniform int pulse_action;     // what a pulse (Pulse every, Trigger) does besides the light: Seed burst plants seeds (try Pulse every 4)

//@int min=0 max=24 value=4
uniform int seed_points;      // seeds at random places of its area, new places each generation
//@slider min=0.0 max=1.0 value=0.25
uniform float seed_edges;     // seeds along the outlines of the mask
//@slider min=0.0 max=1.0 value=0.0
uniform float seed_from_picture;  // seeds where Seed picture is bright, all the time while it grows
//@int min=1 max=24 value=5
uniform int burst_seeds;      // how many seeds a pulse plants (Seed burst), around one random place

//@rgb value=(0.95, 0.85, 0.4)
uniform vec3 color_young;     // Two colours: the young parts
//@rgb value=(0.2, 0.45, 0.6)
uniform vec3 color_old;       // Two colours: the old parts
//@slider min=1.0 max=256.0 value=24.0
uniform float age_span;       // beats until a part has the colour of old age
//@slider min=0.0 max=0.5 value=0.06
uniform float generation_hue; // how far the hue of a generation wanders from the palette
//@slider min=0.0 max=2.0 value=0.6
uniform float glow;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@button
uniform bool transparent;     // the empty parts are transparent: lay it over other layers
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

// ---- the state (pass S) ----
float gr_clock;      // beats since the last turn began
float gr_phase;      // 0 growing, 1 turning
float gr_turn_t;     // beats into the turn
float gr_gen;        // the generation (counts up at each turn, 0..1023)
float gr_progress;   // 0..1 through the turn, 0 while growing
float gr_grow_len;   // how long the last generation grew (its clock when the turn began)
bool gr_regrow;      // the new generation may grow
bool gr_seed_now;    // the frames in which the seeds of the new generation are planted

// Where in the turn the next generation starts, per mode
float gr_regrow_point(int mode) {
    if (mode == 0) return 0.45;   // Wither
    if (mode == 1) return 0.6;    // Burn
    if (mode == 3) return 0.7;    // Recede
    return 0.0;                   // Invert, Reseed: at once
}

void gr_load(sampler2D S) {
    vec4 a = texelFetch(S, ivec2(0, 0), 0);
    vec4 b = texelFetch(S, ivec2(1, 0), 0);
    vec4 c = texelFetch(S, ivec2(2, 0), 0);
    gr_clock = a.x;
    gr_phase = a.y;
    gr_turn_t = a.z;
    gr_gen = a.w;
    gr_grow_len = max(b.w, 0.01);
    gr_progress = gr_phase > 0.5 ? clamp(gr_turn_t / max(turn_length, 0.01), 0.0, 1.0) : 0.0;
    gr_regrow = gr_phase < 0.5 || gr_progress >= gr_regrow_point(cycle_mode);
    gr_seed_now = b.x > 0.5;
}

// The pass S: one frame of the state machine. measured: the share of the area grown, counted this frame
vec4 gr_state_pass(sampler2D last, sampler2D T, ivec2 p, float measured) {
    vec4 a = texelFetch(last, ivec2(0, 0), 0);
    vec4 b = texelFetch(last, ivec2(1, 0), 0);
    vec4 c = texelFetch(last, ivec2(2, 0), 0);
    vec4 d = texelFetch(last, ivec2(3, 0), 0);
    if (iFrame < 3) {
        a = vec4(0.0);
        b = vec4(0.0, measured, 0.0, 1.0);
        c = vec4(iTime, 0.0, 0.0, 0.0);
        d = vec4(0.0);
    }
    // beats of the timeline; while it stands still (or jumps) a beat is half a second
    float dtb = iTime - c.x;
    if (dtb <= 0.0 || dtb > 1.0) dtb = clamp(iTimeDelta * 2.0, 0.0, 0.25);
    float clock = min(a.x + dtb, 9000.0);
    float phase = a.y;
    float turn_t = a.z;
    float gen = a.w;
    float cov = iFrame < 3 ? measured : mix(d.w, measured, 0.08);
    float best = b.y;
    float best_clock = b.z;
    float grow_len = b.w;
    float grow_start = c.w;
    // frames since it last grew (the simulations grow per frame: on a slow computer a beat holds fewer steps)
    float still_frames = min(floor(c.y * 0.5) + 1.0, 1e6);
    if (cov > best + 0.01 || cov < best - 0.25) {
        best = cov;
        best_clock = clock;
        still_frames = 0.0;
    }

    bool want = turn && mod(c.y, 2.0) < 0.5 && iFrame >= 3;
    vec3 pl = mp_pulse(T);
    if (pulse_action == 2 && pl.z > 0.5) want = true;
    if (phase < 0.5 && clock - grow_start > 2.0) {
        if (turn_at < 0.999 && cov >= turn_at) want = true;
        if (turn_every > 0 && clock >= float(turn_every)) want = true;
        if (turn_when_stuck > 0 && clock - max(best_clock, grow_start) >= float(turn_when_stuck) && still_frames > 240.0)
            want = true;
    }
    float fire = 0.0;
    if (want && phase < 0.5) {
        phase = 1.0;
        turn_t = 0.0;
        grow_len = max(clock, 0.01);
        gen = mod(gen + 1.0, 1024.0);
        clock = 0.0;
        best = cov;
        best_clock = 0.0;
        still_frames = 0.0;
        fire = 1.0;
    } else if (phase > 0.5) {
        turn_t += dtb;
        if (turn_t >= turn_length) {
            phase = 0.0;
            turn_t = 0.0;
            grow_start = clock;
            best = cov;
            best_clock = clock;
            still_frames = 0.0;
        }
    }
    float prog = phase > 0.5 ? clamp(turn_t / max(turn_length, 0.01), 0.0, 1.0) : 0.0;
    bool regrow = phase < 0.5 || prog >= gr_regrow_point(cycle_mode);
    float env = fire > 0.5 ? 1.0 : d.z * mix(0.8, 0.985, pulse_decay);
    float life = clamp(cov / max(turn_at, 0.05), 0.0, 1.0);

    if (p.x == 0) return vec4(clock, phase, turn_t, gen);
    bool regrow_ok = regrow && iFrame >= 3;
    // seeds when the new generation may start: later in the turn, or at once (Invert, Reseed) in the frame it begins,
    // for 4 frames; and again every 16 frames while nothing at all is grown (when a shader is added its passes do not
    // all start in the same frame, and the first seeds were lost)
    bool again = measured < 0.002 && iFrame % 16 == 0;
    float seed_now = regrow_ok && (c.z < 0.5 || fire > 0.5 || again) ? 4.0 : max(b.x - 1.0, 0.0);
    if (p.x == 1) return vec4(seed_now, best, best_clock, grow_len);
    if (p.x == 2) return vec4(iTime, still_frames * 2.0 + (turn ? 1.0 : 0.0), regrow_ok ? 1.0 : 0.0, grow_start);
    return vec4(life, prog, env, clamp(cov, 0.0, 1.0));
}

// The uv of coverage sample i of n x n (a new jitter every frame)
vec2 gr_sample_uv(int i, int n) {
    vec2 cell = vec2(float(i % n), float(i / n));
    vec2 j = vec2(mp_rand3(ivec3(i, iFrame, 3)), mp_rand3(ivec3(i, iFrame, 7)));
    return (cell + j) / float(n);
}

// ---- cells ----
float gr_pack(float gen, float birth) { return mod(gen, 4.0) * 10000.0 + clamp(birth, 0.0, 9999.0); }
float gr_cell_gen(float pk) { return floor(pk / 10000.0); }
float gr_cell_birth(float pk) { return pk - floor(pk / 10000.0) * 10000.0; }
float gr_new_cell() { return gr_pack(gr_gen, gr_clock); }
bool gr_is_current(float pk) { return pk >= 0.0 && abs(gr_cell_gen(pk) - mod(gr_gen, 4.0)) < 0.5; }

// A noise per cell for the crumbling of a turn, new each generation
float gr_turn_noise(vec2 uv) {
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 q = vec2(uv.x * a, uv.y) * 9.0 + vec2(gr_gen * 7.13, gr_gen * 3.71);
    return mp_vnoise(q) * 0.65 + mp_vnoise(q * 2.7 + 11.0) * 0.35;
}

// How far a cell has died in the turn: 0 alive .. 1 gone. Cells of the current generation live; the generation
// before dies during the turn in the order of its mode; anything older is gone.
float gr_decay(float pk, vec2 uv) {
    if (pk < 0.0) return 1.0;
    float g = gr_cell_gen(pk);
    float cur = mod(gr_gen, 4.0);
    if (abs(g - cur) < 0.5) return 0.0;
    if (gr_phase < 0.5 || abs(g - mod(gr_gen + 3.0, 4.0)) > 0.5) return 1.0;
    float rank = clamp(gr_cell_birth(pk) / gr_grow_len, 0.0, 1.0);   // 0 the oldest .. 1 the youngest
    float n = gr_turn_noise(uv);
    float o;
    float w;
    if (cycle_mode == 0) { o = rank * 0.7 + n * 0.3; w = 0.35; }            // Wither: the old parts first, crumbling
    else if (cycle_mode == 1) { o = rank * 0.92 + n * 0.08; w = 0.07; }     // Burn: a narrow front along the growth
    else if (cycle_mode == 2) { o = n * 0.55 + rank * 0.2; w = 0.4; }       // Invert: fades while the gaps grow
    else if (cycle_mode == 3) { o = (1.0 - rank) * 0.85 + n * 0.15; w = 0.18; }  // Recede: back into the seeds
    else { o = 0.3 + n * 0.5; w = 0.3; }                                     // Reseed: fades as the new one comes
    return clamp((gr_progress * (1.0 + w) - o) / w, 0.0, 1.0);
}

// The age of a cell in beats (also of the generation before, during a turn)
float gr_age(float pk) {
    if (pk < 0.0) return 0.0;
    float b = gr_cell_birth(pk);
    if (gr_is_current(pk)) return max(gr_clock - b, 0.0);
    return max(gr_grow_len + gr_clock - b, 0.0);
}

// Where it may grow (0..1) from the mask m: by Mask role; with no mask everywhere
float gr_soil(float m) {
    if (mp_mask_mode() == 4 || mask_role == 2) return 1.0;
    return mask_role == 1 ? 1.0 - m : m;
}

// ---- seeds ----
// The random places of the seeds of generation g (uv). Tries a few places and takes the first on the soil (M.r)
vec2 gr_point(sampler2D M, int k) {
    vec2 best = vec2(0.5);
    for (int t = 0; t < 4; t++) {
        ivec3 h = ivec3(int(gr_gen) * 4 + t, k, 0);
        vec2 q = vec2(0.04 + 0.92 * mp_rand3(h + ivec3(0, 0, 17)), 0.04 + 0.92 * mp_rand3(h + ivec3(0, 0, 41)));
        best = q;
        if (texelFetch(M, ivec2(q * vec2(textureSize(M, 0))), 0).r > 0.5) break;
    }
    return best;
}

// Seeds at texel p of a simulation pass (the same size as M), 0..1: the seed points and the outlines in the frame the
// generation starts; a pulse (Seed burst) and the picture in any frame while it may grow. radius in texels.
// edge_run: the length in texels of the runs along the outlines that seed, edge_share: the share of the outline
// they cover at Seed edges = 1, picture_rate: 1 = up to 1 % of the bright texels a frame
float gr_seeds(sampler2D M, sampler2D T, ivec2 p, float radius, float edge_run, float edge_share, float picture_rate) {
    if (!gr_regrow) return 0.0;
    vec2 res = vec2(textureSize(M, 0));
    vec2 pc = vec2(p) + 0.5;
    vec4 mm = texelFetch(M, p, 0);
    if (mm.r < 0.5) return 0.0;
    float s = 0.0;
    if (gr_seed_now) {
        for (int k = 0; k < 24; k++) {
            if (k >= seed_points) break;
            vec2 d = pc - gr_point(M, k) * res;
            s = max(s, 1.0 - smoothstep(radius * 0.6, radius, length(d)));
        }
        if (seed_edges > 0.0) {
            // runs along the outlines, three texels thick (a single texel dies in some patterns)
            ivec2 hi = ivec2(res) - 1;
            float e = max(mm.g, max(max(texelFetch(M, clamp(p + ivec2(1, 0), ivec2(0), hi), 0).g,
                                        texelFetch(M, clamp(p - ivec2(1, 0), ivec2(0), hi), 0).g),
                                    max(texelFetch(M, clamp(p + ivec2(0, 1), ivec2(0), hi), 0).g,
                                        texelFetch(M, clamp(p - ivec2(0, 1), ivec2(0), hi), 0).g)));
            float run = mp_vnoise(pc / max(edge_run, 0.5) + vec2(gr_gen * 17.3, gr_gen * 5.1));
            if (e > 0.5 && run > 1.0 - seed_edges * edge_share) s = 1.0;
        }
    }
    vec3 pl = mp_pulse(T);
    if (pulse_action == 1 && pl.z > 0.5) {
        int ki = int(pl.y);
        vec2 c = vec2(0.1 + 0.8 * mp_rand3(ivec3(ki, 11, 5)), 0.1 + 0.8 * mp_rand3(ivec3(ki, 23, 9))) * res;
        for (int k = 0; k < 24; k++) {
            if (k >= burst_seeds) break;
            float ang = mp_rand3(ivec3(ki, k, 31)) * MP_TAU;
            float r = sqrt(mp_rand3(ivec3(ki, k, 37))) * res.y * 0.09;
            vec2 d = pc - (c + vec2(cos(ang), sin(ang)) * r);
            s = max(s, 1.0 - smoothstep(radius * 0.6, radius, length(d)));
        }
    }
    if (seed_from_picture > 0.0 && gr_seed_picture_linked) {
        vec3 pc3 = texture(seed_picture, pc / res).rgb;
        float l = max(pc3.r, max(pc3.g, pc3.b));
        if (mp_rand3(ivec3(p, iFrame)) < seed_from_picture * 0.01 * picture_rate * smoothstep(0.35, 0.8, l)) s = 1.0;
    }
    return s;
}

// ---- colours ----
// Palettes from young (t = 0) to old (t = 1): Moss, Coral, Lichen, Embers, Ice, Deep sea, Two colours
vec3 gr_palette(int pal, float t) {
    vec3 a;
    vec3 b;
    vec3 c;
    if (pal == 0) { a = vec3(0.62, 0.92, 0.28); b = vec3(0.22, 0.55, 0.14); c = vec3(0.32, 0.33, 0.12); }
    else if (pal == 1) { a = vec3(1.0, 0.68, 0.52); b = vec3(0.98, 0.32, 0.38); c = vec3(0.48, 0.12, 0.38); }
    else if (pal == 2) { a = vec3(0.86, 0.92, 0.68); b = vec3(0.62, 0.74, 0.5); c = vec3(0.95, 0.62, 0.18); }
    else if (pal == 3) { a = vec3(1.0, 0.92, 0.55); b = vec3(1.0, 0.42, 0.06); c = vec3(0.42, 0.06, 0.03); }
    else if (pal == 4) { a = vec3(0.94, 0.98, 1.0); b = vec3(0.62, 0.86, 1.0); c = vec3(0.3, 0.55, 0.95); }
    else if (pal == 5) { a = vec3(0.35, 1.0, 0.88); b = vec3(0.1, 0.48, 0.95); c = vec3(0.32, 0.1, 0.55); }
    else { a = color_young; b = mix(color_young, color_old, 0.5); c = color_old; }
    t = clamp(t, 0.0, 1.0);
    return t < 0.5 ? mix(a, b, smoothstep(0.0, 0.5, t)) : mix(b, c, smoothstep(0.5, 1.0, t));
}

// Turns the hue of a colour (Rodrigues around the grey axis)
vec3 gr_hue_turn(vec3 c, float turns) {
    float a = turns * MP_TAU;
    vec3 k = vec3(0.57735);
    float cs = cos(a);
    return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

// The colour from the look of a cell (gr_look): its place from young to old, its generation (0 the current one, 1
// the one before) and its variation (0..1)
vec3 gr_color(vec4 look) {
    vec3 col = gr_palette(palette, look.x);
    float g = gr_gen - look.z;
    float wander = sin(g * 2.39996) * 1.5 + 0.5 * sin(g * 0.61);
    return max(gr_hue_turn(col, wander * generation_hue + (look.w - 0.5) * 0.08), 0.0);
}

// The look of a cell for the colours, made per texel of the simulation so that the picture can read it bilinear
// (smooth at full size): x the place from young to old (0..1), y how far it died (gr_decay), z the generation (0 the
// current one, 1 the one before), w its variation. Empty texels look like a young, living cell.
vec4 gr_look(float pk, float variation, vec2 uv) {
    if (pk < 0.0) return vec4(0.0, 0.0, 0.0, variation);
    float t = 1.0 - exp(-gr_age(pk) / max(age_span, 0.5));
    return vec4(t, gr_decay(pk, uv), gr_is_current(pk) ? 0.0 : 1.0, variation);
}

// Glowing colour of a fire: 0 dark red .. 1 white-yellow
vec3 gr_fire(float x) {
    x = clamp(x, 0.0, 1.0);
    return vec3(1.0, 0.35, 0.05) * smoothstep(0.0, 0.4, x) + vec3(0.0, 0.5, 0.25) * smoothstep(0.35, 0.8, x)
         + vec3(0.0, 0.15, 0.55) * smoothstep(0.7, 1.0, x);
}

// The look of a cell that is dying (d 0..1 from gr_decay; n a noise of the pixel 0..1): the colour, and how much of
// the cell is left (keep, 0..1); emit: light of its own (the fire of Burn, the glow of Recede)
vec3 gr_dying(vec3 col, float d, float n, out float keep, out vec3 emit) {
    emit = vec3(0.0);
    keep = 1.0;
    if (d <= 0.0) return col;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    if (cycle_mode == 1) {
        // Burn: glowing in the front, then charcoal with embers that go out
        float band = smoothstep(0.0, 0.15, d) * (1.0 - smoothstep(0.45, 0.8, d));
        float flick = 0.6 + 0.4 * n;
        emit = gr_fire(band * flick * 1.2) * band * 2.2;
        col = mix(col, vec3(0.05, 0.04, 0.035), smoothstep(0.1, 0.5, d));
        float ember = step(0.78, n) * (1.0 - smoothstep(0.5, 0.95, d));
        emit += vec3(1.0, 0.3, 0.05) * ember * 0.8;
        keep = 1.0 - smoothstep(0.55, 1.0, d) * (0.5 + 0.5 * n);
        keep *= 1.0 - smoothstep(0.85, 1.0, d);
    } else if (cycle_mode == 3) {
        // Recede: lights up and draws back
        emit = col * smoothstep(0.0, 0.3, d) * (1.0 - smoothstep(0.5, 1.0, d)) * 0.9;
        keep = 1.0 - smoothstep(0.35, 1.0, d);
    } else if (cycle_mode == 2) {
        // Invert: pales into a ghost of itself
        col = mix(col, vec3(lum) * vec3(0.7, 0.8, 1.0), smoothstep(0.0, 0.6, d));
        keep = 1.0 - smoothstep(0.1, 1.0, d);
    } else {
        // Wither, Reseed: dries out, browns, crumbles from the edges of the noise
        vec3 dry = GR_DRY * (0.5 + lum);
        col = mix(col, dry, smoothstep(0.0, 0.55, d));
        keep = clamp((1.0 - d) * 2.2 - (1.0 - n) * 0.9, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, d));
    }
    return col;
}

// The mask in red over the picture (calibration), and the transparent background
vec4 gr_finish(vec3 rgb, float cover, vec2 uv) {
    float alpha = transparent ? clamp(cover, 0.0, 1.0) : 1.0;
    if (show_mask > 0.0) {
        float m = mp_mask(uv);
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask * m);
    }
    return vec4(rgb, alpha);
}
