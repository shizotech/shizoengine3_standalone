//@settings dtype=float32 format=rgba
// --- MaskSand (#586, projection mapping building blocks: simulations in the mask) ---
// Sand or a liquid that pours from the top, piles up on the top surfaces of the mapped objects and runs off their
// edges (or fills the white shapes like an hourglass). A cellular automaton on blocks of 2 x 2 cells at a quarter of
// the size, two steps a frame (passes A, B); no grain is lost or made twice. A pulse pours a burst, turns a picture
// into sand, shakes the piles, opens the floor or clears the picture.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D B;
uniform sampler2D M;

//@enum options=(Grains, Smooth, Glow) value=0
uniform int look;             // Grains: every cell a grain; Smooth: dunes and a liquid surface; Glow: points of light
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;
//@slider min=0.0 max=1.0 value=0.5
uniform float relief;         // light from the top on the surfaces of the piles
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Transparent, Grains over it) value=0
uniform int obstacle_view;    // what the objects show
//@rgb value=(0.12, 0.12, 0.14)
uniform vec3 obstacle_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

// The grains around gp (cells), bilinear: the share of full cells, their mean colour and the share of liquid
float sand_smooth(vec2 gp, out vec3 col, out float liq) {
    ivec2 size = textureSize(B, 0);
    vec2 q = gp - 0.5;
    ivec2 i0 = ivec2(floor(q));
    vec2 f = fract(q);
    float occ = 0.0;
    col = vec3(0.0);
    liq = 0.0;
    for (int k = 0; k < 4; k++) {
        ivec2 o = ivec2(k & 1, k >> 1);
        vec4 v = texelFetch(B, clamp(i0 + o, ivec2(0), size - 1), 0);
        float w = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
        float full = step(0.5, v.a);
        occ += w * full;
        col += w * full * v.rgb;
        liq += w * (sd_kind(v) == 2 ? 1.0 : 0.0);
    }
    col /= max(occ, 1e-3);
    return occ;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    ivec2 gres = textureSize(B, 0);
    vec2 gp = uv * vec2(gres);
    ivec2 c = ivec2(floor(gp));
    ivec2 hi = gres - 1;
    vec4 g = texelFetch(B, clamp(c, ivec2(0), hi), 0);
    vec3 rgb = background;
    float a_out = 1.0;

    if (look == 0) {
        if (g.a > 0.5) {
            // a grain: its colour, lit from above where nothing lies on it, darker in the pile
            vec2 f = fract(gp);
            float up = texelFetch(B, clamp(c + ivec2(0, 1), ivec2(0), hi), 0).a > 0.5 ? 0.0 : 1.0;
            float shade = 1.0 - relief * 0.35 * (1.0 - up) + relief * 0.35 * up * smoothstep(0.4, 1.0, f.y);
            float edge = smoothstep(0.0, 0.18, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
            vec3 col = g.rgb * shade * mix(0.75, 1.0, edge);
            if (sd_kind(g) == 2) col = mix(col, col * 1.3 + 0.1, up * 0.6);
            rgb = col * brightness;
        }
    } else if (look == 1) {
        // the occupancy, smooth, and its slope for the light
        vec3 col;
        float liq;
        float occ = sand_smooth(gp, col, liq);
        vec3 c2;
        float l2;
        float ox = sand_smooth(gp + vec2(1.0, 0.0), c2, l2) - sand_smooth(gp - vec2(1.0, 0.0), c2, l2);
        float oy = sand_smooth(gp + vec2(0.0, 1.0), c2, l2) - sand_smooth(gp - vec2(0.0, 1.0), c2, l2);
        float fill = smoothstep(0.35, 0.65, occ);
        vec3 n = normalize(vec3(-ox, -oy, 0.6));
        float diff = clamp(dot(n, normalize(vec3(-0.3, 0.8, 0.5))), 0.0, 1.0);
        col = col * mix(1.0, 0.55 + 0.75 * diff, relief);
        col += liq * pow(diff, 12.0) * 0.6;
        rgb = mix(background, col * brightness, fill);
    } else {
        // glow: every grain a point of light
        vec2 f = fract(gp) - 0.5;
        float d = length(f);
        if (g.a > 0.5) rgb += g.rgb * brightness * (exp(-d * d * 8.0) * 1.2);
        rgb += mp_bilinear(B, gp).rgb * brightness * 0.25;
    }

    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = smoothstep(0.25, 0.75, mp_bilinear_uv(M, uv).r);
    float s = sd_solid_of(m) ? 1.0 : 0.0;
    if (mp_mask_mode() != 4) s = mask_role == 1 ? 1.0 - m : m;
    else s = 0.0;
    if (obstacle_view == 0) rgb *= 1.0 - s;
    else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, s);
    else if (obstacle_view == 2) a_out = 1.0 - s;

    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        a_out = max(a_out, show_mask);
    }
    fragColor = vec4(rgb, a_out);
}
