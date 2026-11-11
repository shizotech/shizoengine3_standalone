//@settings dtype=float32 format=rgba
// --- RegionChase (#586, projection mapping building blocks) ---
// Splits the mask into its regions (each white shape, or each colour of an ID map: the windows of a facade, the
// boxes of a stage) and plays each one by itself: a chase or steps across them in an order you pick, random rooms
// on the beat, flicker, waves, levels that fill up; filled with a colour, a gradient, an inner glow, an outline, or
// a picture (the whole picture in every region, or one picture across all). The regions are labelled on a quarter of
// the size (passes M, K, L1..L4, B1..B4: keys, a change check, labels by pointer jumping, the box of each region);
// when the mask changes they are found again within a few frames.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D L4;
uniform sampler2D B4;
uniform sampler2D T;
uniform sampler2D fill_picture;   // optional: the picture for the fill styles Picture in each region / Picture across

//@enum options=(Chase, Step, Random, Flicker, Wave, Pulse, Fill up) value=1
uniform int pattern;
//@enum options=(Left to right, Right to left, Top to bottom, Bottom to top, Random, By size, From the middle) value=0
uniform int order;              // the order the regions are played in
//@slider min=-4.0 max=4.0 value=1.0
uniform float speed;            // steps or sweeps per beat (Sync) or second (Free)
//@int min=1 max=64 value=6
uniform int groups;             // Step: steps in one round (e.g. the columns of windows)
//@slider min=0.01 max=1.0 value=0.3
uniform float chase_width;      // Chase: share of the regions that is lit
//@slider min=0.0 max=1.0 value=0.35
uniform float density;          // Random: share of the regions that is on
//@slider min=0.0 max=1.0 value=0.5
uniform float fade;             // Step, Random: how much a region fades before the next step
//@enum options=(Solid, Gradient, Inner glow, Outline, Picture in each region, Picture across) value=2
uniform int fill_style;
//@slider min=0.5 max=40.0 value=4.0
uniform float outline_px;       // Outline, Inner glow: pixels
//@enum options=(Two colours, Rainbow by order, Random hues, Warm rooms, One colour) value=1
uniform int palette;
//@rgb value=(0.2, 0.8, 1.0)
uniform vec3 color_a;
//@rgb value=(1.0, 0.3, 0.6)
uniform vec3 color_b;
//@slider min=0.0 max=1.0 value=0.06
uniform float off_level;        // how bright a region is when it is off
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;
//@slider min=0.0 max=2.0 value=0.5
uniform float pulse_amount;     // all regions flash at a pulse (Pulse every, Trigger)
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Final, Regions) value=0
uniform int debug_view;         // Regions: each region in its own colour with its box, to check the mask
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;        // calibration: the mask in red over the picture

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    vec2 uv = fragCoord / iResolution.xy;
    float a = iResolution.x / iResolution.y;
    vec2 lres = vec2(textureSize(L4, 0));

    // the region of this pixel: the key at full size, the label of the nearest texel with that key
    float cover = 1.0;
    float key;
    if (region_source == 0 || mp_mask_mode() != 1) {
        cover = mask_blur < 0.25 ? mp_mask(uv) : mp_bilinear_uv(M, uv).r;
        key = cover > 0.02 ? 1.0 : 0.0;
        cover = clamp(cover * 1.5, 0.0, 1.0);
    } else {
        key = rc_key(uv);
    }
    vec4 lab = vec4(0.0);
    if (key > 0.5) {
        vec2 q = uv * lres;
        ivec2 c = ivec2(floor(q));
        float bd = 1e9;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                ivec2 t = clamp(c + ivec2(x, y), ivec2(0), ivec2(lres) - 1);
                vec4 l = texelFetch(L4, t, 0);
                if (l.w < 0.5 || abs(l.z - key) > 0.5) continue;
                vec2 e = vec2(t) + 0.5 - q;
                float d2 = dot(e, e);
                if (d2 < bd) { bd = d2; lab = l; }
            }
        }
    }
    vec3 pl = mp_pulse(T);
    if (lab.w < 0.5) {
        vec3 bg = background;
        if (show_mask > 0.0) bg = mix(bg, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * clamp(mp_bilinear_uv(M, uv).r, 0.0, 1.0));
        fragColor = vec4(bg, 1.0);
        return;
    }

    float h = mp_rand2(ivec2(lab.xy) + ivec2(91, 7));
    vec4 bb = texelFetch(B4, ivec2(lab.xy), 0);
    if (bb.z < bb.x) bb = vec4(lab.xy, lab.xy);
    vec2 bmin = bb.xy / lres;
    vec2 bmax = (bb.zw + 1.0) / lres;
    vec2 size = max(bmax - bmin, 1.0 / lres);
    vec2 centre = (bmin + bmax) * 0.5;
    vec2 local = clamp((uv - bmin) / size, 0.0, 1.0);

    if (debug_view == 1) {
        vec2 epx = min(local, 1.0 - local) * size * iResolution.xy;
        float edge = 1.0 - smoothstep(1.0, 2.5, min(epx.x, epx.y));
        fragColor = vec4(mix(mp_hue(h) * 0.8, vec3(1.0), edge) * cover, 1.0);
        return;
    }

    float ord;
    if (order == 1) ord = 1.0 - centre.x;
    else if (order == 2) ord = 1.0 - centre.y;
    else if (order == 3) ord = centre.y;
    else if (order == 4) ord = h;
    else if (order == 5) ord = clamp(sqrt(size.x * size.y * a) * 2.0, 0.0, 1.0);
    else if (order == 6) ord = clamp(length((centre - 0.5) * vec2(a, 1.0)) / (0.5 * length(vec2(a, 1.0))), 0.0, 1.0);
    else ord = centre.x;
    ord = clamp(ord, 0.0, 0.9999);

    float t = iTime * speed;
    float v;
    if (pattern == 0) {
        float f = fract(ord - t);
        float w = max(chase_width, 0.01);
        v = f < w ? pow(1.0 - f / w, 1.5) : 0.0;
    } else if (pattern == 1) {
        float g = float(max(groups, 1));
        float idx = floor(ord * g);
        float cur = mod(floor(t), g);
        v = (idx == cur ? 1.0 : 0.0) * (1.0 - fade * fract(t));
    } else if (pattern == 2) {
        float st = floor(t);
        v = (mp_rand3(ivec3(ivec2(lab.xy), int(st) + 5000)) < density ? 1.0 : 0.0) * (1.0 - fade * fract(t));
    } else if (pattern == 3) {
        float n = mp_vnoise(vec2(h * 173.0, t * 4.0)) * 0.7 + mp_vnoise(vec2(h * 91.0 + 7.0, t * 11.0)) * 0.3;
        v = smoothstep(0.25, 0.75, n);
    } else if (pattern == 4) {
        v = 0.5 + 0.5 * cos(MP_TAU * (ord - t));
    } else if (pattern == 5) {
        v = pl.x;
    } else {
        float level = 0.5 + 0.5 * sin(MP_TAU * (t * 0.5 + h));
        v = 1.0 - smoothstep(level - 0.02, level + 0.02, local.y);
    }
    float b = (mix(off_level, 1.0, clamp(v, 0.0, 1.0)) + pulse_amount * pl.x) * brightness;

    vec3 col;
    if (palette == 0) col = h < 0.5 ? color_a : color_b;
    else if (palette == 2) col = mp_hue(h);
    else if (palette == 3) {
        col = mix(vec3(1.0, 0.62, 0.3), vec3(1.0, 0.9, 0.75), fract(h * 7.0));
        if (h > 0.86) col = vec3(0.55, 0.7, 1.0);   // a room with a TV
    } else if (palette == 4) col = color_a;
    else col = mp_hue(ord * 0.85 + iTime * 0.02);

    vec2 epx = min(local, 1.0 - local) * size * iResolution.xy;
    float e = min(epx.x, epx.y);
    vec3 rgb;
    if (fill_style == 1) rgb = col * b * mix(0.3, 1.0, local.y);
    else if (fill_style == 2) rgb = col * b * (0.35 + 0.9 * exp(-e / max(outline_px * 3.0, 1.0)));
    else if (fill_style == 3) rgb = col * b * (1.0 - smoothstep(outline_px - 0.75, outline_px + 0.75, e));
    else if (fill_style == 4) rgb = texture(fill_picture, local).rgb * b;
    else if (fill_style == 5) rgb = texture(fill_picture, uv).rgb * b;
    else rgb = col * b;

    rgb = mix(background, rgb, cover);
    if (show_mask > 0.0) rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * clamp(mp_bilinear_uv(M, uv).r, 0.0, 1.0));
    fragColor = vec4(rgb, 1.0);
}
