//@settings dtype=float32 format=rgba
// --- MaskFire (#586, projection mapping building blocks: simulations in the mask) ---
// Flames that burn on the mapped objects and climb up along their outlines, with embers that fly up. A heat field on
// half the size (pass H) is carried up by a swirling flow that runs along the outlines and around the objects, cooled
// into tongues and fed on the top edges, all around the objects, on their faces, at the bottom or by a picture; the
// embers live on a grid of cells (pass K). A pulse flares the fire, throws embers or lights all the outlines at once.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D H;
uniform sampler2D K;
uniform sampler2D L;
uniform sampler2D M;
uniform sampler2D T;

//@enum options=(Fire, Blue gas, Green, Magic, Two colours) value=0
uniform int palette;
//@rgb value=(0.9, 0.2, 0.05)
uniform vec3 color_a;         // Two colours: the cool part
//@rgb value=(1.0, 0.85, 0.4)
uniform vec3 color_b;         // Two colours: the hot part
//@slider min=0.0 max=3.0 value=1.2
uniform float brightness;
//@slider min=0.2 max=3.0 value=1.0
uniform float flame_height;   // stretches the colours: higher shows the cooler parts too
//@rgb value=(0.18, 0.17, 0.17)
uniform vec3 smoke_color;
//@slider min=0.3 max=6.0 value=2.2
uniform float ember_size;     // pixels
//@slider min=0.0 max=3.0 value=0.9
uniform float ember_brightness;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Lit by the fire, Colour, Transparent, Fire over it) value=1
uniform int obstacle_view;    // what the objects show: Lit by the fire glows on the real object where the flames are near
//@rgb value=(0.1, 0.1, 0.11)
uniform vec3 obstacle_color;
//@enum options=(Final, Heat, Flow) value=0
uniform int debug_view;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

vec3 ramp4(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    t = clamp(t, 0.0, 1.0) * 3.0;
    if (t < 1.0) return mix(a, b, t);
    if (t < 2.0) return mix(b, c, t - 1.0);
    return mix(c, d, t - 2.0);
}

vec3 fire_color(float t) {
    vec3 k = vec3(0.0);
    if (palette == 1) return ramp4(t, k, vec3(0.05, 0.1, 0.6), vec3(0.15, 0.55, 1.0), vec3(0.85, 0.95, 1.0)) * smoothstep(0.0, 0.2, t);
    if (palette == 2) return ramp4(t, k, vec3(0.05, 0.4, 0.05), vec3(0.4, 0.95, 0.15), vec3(0.95, 1.0, 0.7)) * smoothstep(0.0, 0.2, t);
    if (palette == 3) return ramp4(t, k, vec3(0.35, 0.02, 0.5), vec3(0.95, 0.2, 0.85), vec3(1.0, 0.85, 1.0)) * smoothstep(0.0, 0.2, t);
    if (palette == 4) return ramp4(t, k, color_a, color_b, vec3(1.0)) * smoothstep(0.0, 0.2, t);
    return ramp4(t, k, vec3(0.55, 0.04, 0.0), vec3(1.0, 0.38, 0.03), vec3(1.0, 0.85, 0.45)) * smoothstep(0.0, 0.15, t)
         + vec3(0.6, 0.55, 0.4) * smoothstep(1.0, 1.6, t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 hres = vec2(textureSize(H, 0));
    vec4 hs = mp_bilinear(H, uv * hres);
    float heat = hs.r;
    float t = heat * 0.75 / max(flame_height, 0.2);
    vec3 fire = fire_color(t);

    vec3 rgb = background;
    float smk = clamp(hs.g * smoke * 1.5, 0.0, 0.85) * (1.0 - smoothstep(0.1, 0.5, heat));
    rgb = mix(rgb, smoke_color, smk);
    rgb += fire * brightness;

    // the embers: a dot with a short tail below it, from the cells around this pixel
    ivec2 kres = textureSize(K, 0);
    float cell = iResolution.x / float(kres.x);
    vec2 kc = fragCoord / cell;
    ivec2 c0 = ivec2(floor(kc));
    float rad = ember_size * iResolution.y / 1080.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 n = c0 + ivec2(x, y);
            if (n.x < 0 || n.y < 0 || n.x >= kres.x || n.y >= kres.y) continue;
            vec4 e = texelFetch(K, n, 0);
            if (e.a < 0.5) continue;
            vec2 d = (kc - e.xy) * cell;
            d.y = d.y > 0.0 ? d.y : d.y * 0.35;          // the tail hangs below the ember
            float life = (40.0 + 110.0 * (e.a - 1.0)) * ember_life;
            float age = clamp(e.b / max(life, 1.0), 0.0, 1.0);
            float flick = 0.6 + 0.4 * sin(e.b * 0.9 + e.a * 50.0);
            float g = exp(-dot(d, d) / (rad * rad)) * (1.0 - age) * flick;
            rgb += fire_color(1.0 - age * 0.6) * g * ember_brightness * 1.5;
        }
    }

    // the objects
    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = fr_mask(M, uv);
    float s = fr_wall_of(m);
    if (mask_role == 2) s = mp_mask_mode() == 4 ? 0.0 : m;
    float alpha = 1.0;
    if (obstacle_view == 0) rgb *= 1.0 - s;
    else if (obstacle_view == 1) {
        // the light of the flames near the object, as a glow on its surface
        vec2 lres = vec2(textureSize(L, 0));
        float near = 0.0;
        for (int k = 0; k < 4; k++) {
            vec2 o = vec2(k == 0 ? 1.0 : (k == 1 ? -1.0 : 0.0), k == 2 ? 1.0 : (k == 3 ? -1.0 : 0.0)) * 1.5;
            near += mp_bilinear(L, uv * lres + o).r;
        }
        near *= 0.25;
        rgb = mix(rgb, fire_color(0.45 + near * 0.3) * near * 1.4 * brightness + obstacle_color * 0.3, s);
    } else if (obstacle_view == 2) rgb = mix(rgb, obstacle_color, s);
    else if (obstacle_view == 3) alpha = 1.0 - s;

    if (debug_view == 1) rgb = vec3(heat * 0.5, hs.g * 0.5, s * 0.3);
    if (debug_view == 2) {
        vec2 v = fr_velocity(M, uv);
        rgb = mp_hue(atan(v.y, v.x) / MP_TAU + 0.5) * clamp(length(v) * 0.25, 0.0, 1.0) + vec3(s * 0.2);
    }
    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
