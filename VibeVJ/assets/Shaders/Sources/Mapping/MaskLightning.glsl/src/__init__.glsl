//@settings dtype=float32 format=rgba
// --- MaskLightning (#586, projection mapping building blocks: simulations in the mask) ---
// Electric arcs that jump between the mapped objects, strike down onto them from the top, leap to the frame, crawl
// along their outlines or burn between two electrodes; at each pulse (a flash that flickers out) and / or all the
// time (crackling arcs). Pass L makes the arcs by midpoint displacement between two ends found on the outlines of the
// mask (a jump flood at half size, passes M, E, J1..J10); this pass draws a hot core, a coloured glow, the spots where
// they hit, a flash of the objects and of the sky, and plasma along the outlines.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D L;
uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

//@slider min=0.3 max=8.0 value=1.6
uniform float core_width;     // pixels
//@slider min=2.0 max=150.0 value=22.0
uniform float glow_width;     // pixels
//@slider min=0.0 max=3.0 value=1.4
uniform float glow;
//@rgb value=(0.45, 0.6, 1.0)
uniform vec3 arc_color;
//@rgb value=(0.9, 0.95, 1.0)
uniform vec3 core_color;
//@slider min=0.0 max=3.0 value=1.2
uniform float brightness;
//@slider min=0.0 max=3.0 value=1.0
uniform float hit_glow;       // a glow where an arc hits
//@slider min=0.0 max=1.0 value=0.25
uniform float object_flash;   // the objects light up with the arcs
//@slider min=0.0 max=1.0 value=0.12
uniform float sky_flash;      // the background lights up with a strike
//@slider min=0.0 max=2.0 value=0.25
uniform float plasma;         // a flickering glow along the outlines while arcs burn
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Outline, Transparent, Arcs over it) value=0
uniform int obstacle_view;    // what the objects show (plus the flash)
//@rgb value=(0.1, 0.1, 0.14)
uniform vec3 obstacle_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

float seg_d(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = fragCoord;
    float scale = iResolution.y / 1080.0;
    float cw = core_width * scale;
    float gw = glow_width * scale;
    float reach = gw * 5.0 + cw * 3.0;

    vec3 col = vec3(0.0);
    float total = 0.0;
    float flash = 0.0;
    for (int i = 0; i < 12; i++) {
        vec4 inf = texelFetch(L, ivec2(34, i), 0);
        if (inf.z < 0.5 || inf.x < 0.005) continue;
        float br = inf.x;
        if (inf.y < 0.5) {
            total += br;
            flash += br * (inf.w > 0.5 ? 1.0 : 0.25);
        }
        vec4 box = texelFetch(L, ivec2(33, i), 0);
        if (p.x < box.x - reach || p.y < box.y - reach || p.x > box.z + reach || p.y > box.w + reach) continue;
        float d = 1e5;
        vec2 prev = texelFetch(L, ivec2(0, i), 0).xy;
        vec2 first = prev;
        for (int v = 1; v <= 32; v++) {
            vec2 cur = texelFetch(L, ivec2(v, i), 0).xy;
            d = min(d, seg_d(p, prev, cur));
            prev = cur;
        }
        float w = inf.y > 0.5 ? cw * 0.6 : cw;
        float core = exp(-(d * d) / (w * w));
        float g = glow * exp(-d / gw) * 0.45 + glow * exp(-d / (gw * 0.25)) * 0.35;
        col += (core_color * core * 1.6 + arc_color * g) * br;
        if (inf.y < 0.5) {
            // the ends: where the arc hits
            float de = min(length(p - first), length(p - prev));
            col += (arc_color + core_color * 0.5) * hit_glow * br * exp(-de / (gw * 0.4)) * 0.8;
        }
    }

    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = smoothstep(0.35, 0.65, mp_bilinear_uv(M, uv).r);
    if (mp_mask_mode() == 4) m = 0.0;
    vec3 rgb = background + arc_color * sky_flash * min(flash, 1.5) * 0.5;
    float alpha = 1.0;
    if (obstacle_view == 0) rgb *= 1.0 - m;
    else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, m);
    else if (obstacle_view == 2) {
        vec2 n;
        float sd = jfa_signed(J10, M, fragCoord, n);
        rgb = mix(rgb * (1.0 - m), obstacle_color * 3.0, 1.0 - smoothstep(0.8, 2.0, abs(sd)));
    } else if (obstacle_view == 3) alpha = 1.0 - m;
    // the objects flash with the arcs, the outlines carry plasma
    rgb += m * mix(arc_color, core_color, 0.5) * object_flash * min(flash, 1.5);
    if (plasma > 0.0 && total > 0.0 && mp_mask_mode() != 4) {
        vec2 n;
        float sd = jfa_signed(J10, M, fragCoord, n);
        float t = float(iFrame);
        float nz = mp_vnoise(fragCoord / (14.0 * scale) + vec2(t * 0.37, -t * 0.21));
        float band = exp(-abs(sd) / (3.0 * scale)) * smoothstep(0.45, 0.85, nz);
        rgb += arc_color * band * plasma * min(total, 1.0) * 1.5;
    }
    rgb += col * brightness;
    if (obstacle_view == 3) alpha = max(alpha, clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0));

    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
