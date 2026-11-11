//@settings dtype=float32 format=rgba
// --- MaskContours (#586, projection mapping building blocks) ---
// Light that grows out of the mapped objects, or into them: glow, contour lines that flow, ripples sent out at the
// beat, offset outlines with a chase, a heat map. All from the distance to the outline of the mask (passes M, E,
// J1..J10: a jump flood at half size), exact in pixels of the full picture.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

//@enum options=(Glow, Contour lines, Ripples, Offset outlines, Heat map) value=1
uniform int style;
//@enum options=(Outside, Inside, Both) value=0
uniform int side;               // where the light is: around the objects, in them, or both
//@slider min=2.0 max=200.0 value=28.0
uniform float spacing;          // pixels between two lines
//@slider min=0.5 max=40.0 value=3.0
uniform float line_width;       // pixels
//@slider min=-4.0 max=4.0 value=0.5
uniform float speed;            // lines per beat; negative: towards the outline
//@slider min=10.0 max=2000.0 value=420.0
uniform float reach;            // pixels: how far from the outline the light goes before it is gone
//@slider min=1.0 max=400.0 value=60.0
uniform float glow_width;       // Glow: pixels
//@int min=1 max=24 value=6
uniform int outline_count;      // Offset outlines: how many
//@slider min=10.0 max=1500.0 value=360.0
uniform float ripple_speed;     // Ripples: pixels per beat
//@slider min=0.0 max=60.0 value=0.0
uniform float warp;             // pixels the lines wobble (noise)
//@slider min=0.1 max=20.0 value=3.0
uniform float warp_scale;
//@slider min=0.0 max=2.0 value=0.8
uniform float pulse_amount;     // all lines flash at a pulse (Pulse every, Trigger)
//@enum options=(Two colours, Rainbow, Palette by distance) value=0
uniform int color_mode;
//@rgb value=(0.3, 0.9, 1.0)
uniform vec3 color_near;        // at the outline
//@rgb value=(0.4, 0.1, 1.0)
uniform vec3 color_far;
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;
//@slider min=0.0 max=1.0 value=0.0
uniform float fill;             // fills the objects themselves
//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 fill_color;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;        // calibration: the mask in red over the picture

float line_at(float x, float w) {
    // a line of w pixels at x = 0 (x in pixels), anti-aliased
    return 1.0 - smoothstep(w * 0.5 - 0.75, w * 0.5 + 0.75, abs(x));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 n;
    float sd = jfa_signed(J10, M, fragCoord, n);
    float a = iResolution.x / iResolution.y;
    if (warp > 0.0) {
        vec2 q = uv * vec2(a, 1.0) * warp_scale;
        sd += (mp_vnoise(q + iTime * 0.15) + 0.5 * mp_vnoise(q * 2.1 - iTime * 0.1) - 0.75) * warp * 1.3;
    }
    float x = side == 0 ? sd : (side == 1 ? -sd : abs(sd));
    bool on_side = x >= 0.0;
    x = max(x, 0.0);
    float fade = on_side ? 1.0 - smoothstep(reach * 0.5, reach, x) : 0.0;
    vec3 pl = mp_pulse(T);

    float v = 0.0;
    if (style == 0) {
        v = exp(-x / max(glow_width, 1.0)) * (0.8 + 0.6 * pl.x * pulse_amount);
    } else if (style == 1) {
        float sp = max(spacing, 2.0);
        float f = x - iTime * speed * sp;
        float k = f - sp * floor(f / sp + 0.5);
        v = line_at(k, line_width) * (0.55 + pulse_amount * pl.x);
        v += 0.25 * exp(-x / (sp * 0.6));
    } else if (style == 2) {
        // a ring leaves the outline at every pulse beat (Pulse every), the last four are out at once
        float every = float(max(pulse_every, 1));
        for (int k = 0; k < 4; k++) {
            float age = fract(iTime / every) + float(k);
            float r = age * every * ripple_speed;
            float ring = line_at(x - r, line_width + age * 2.0) + 0.35 * line_at(x - r, (line_width + age * 2.0) * 4.0);
            v += ring * exp(-age * 1.1);
        }
        v += 0.3 * exp(-x / 6.0) * (1.0 + pl.x * pulse_amount);
    } else if (style == 3) {
        float sp = max(spacing, 2.0);
        float idx = floor(x / sp + 0.5);
        float k = x - idx * sp;
        float cnt = float(max(outline_count, 1));
        float chase = fract((idx - iTime * speed * cnt) / cnt);
        float lit = 0.25 + 0.75 * pow(1.0 - chase, 3.0);
        v = idx < cnt ? line_at(k, line_width) * lit * (1.0 + pl.x * pulse_amount) : 0.0;
    } else {
        v = 1.0;
    }
    v *= fade;

    float t = clamp(x / max(reach, 1.0), 0.0, 1.0);
    vec3 col;
    if (color_mode == 1) col = mp_hue(t * 1.5 - iTime * 0.05);
    else if (color_mode == 2) col = mix(mix(color_near, vec3(1.0, 0.95, 0.6), smoothstep(0.0, 0.3, t)), color_far, smoothstep(0.3, 1.0, t));
    else col = mix(color_near, color_far, t);
    if (style == 4) {
        // heat map: bands of colour by distance
        float b = floor(x / max(spacing, 2.0));
        col = mp_hue(0.66 - clamp(b * max(spacing, 2.0) / max(reach, 1.0), 0.0, 1.0) * 0.66 + iTime * speed * 0.02);
        v = fade;
    }

    vec3 rgb = background + col * v * brightness;
    float inside = clamp(0.5 - sd, 0.0, 1.0);
    rgb = mix(rgb, fill_color * (1.0 + pl.x * pulse_amount * 0.5), fill * inside);

    if (show_mask > 0.0) rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * mp_bilinear_uv(M, uv).r);
    fragColor = vec4(rgb, 1.0);
}
