//@settings dtype=float32 format=rgba
// --- MaskReveal (#586, projection mapping building blocks) ---
// Shows the input only on the mapped surfaces of the mask, cut cleanly (grow / shrink, soft edge in pixels), and
// wipes it in: a fade, across, from a point, from the outlines inwards, from the middle of each surface outwards, a
// noise dissolve; by hand (a fader, MIDI), in a loop of n beats, or at each pulse. A bright front runs with the wipe.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D input;   // the picture shown on the surfaces
uniform sampler2D M;
uniform sampler2D J10;
uniform sampler2D T;

//@enum options=(Fade, Linear, Radial, From the outlines, From the middle, Noise) value=3
uniform int wipe;
//@enum options=(By hand, Loop, At each pulse) value=1
uniform int drive;
//@slider min=0.0 max=1.0 value=1.0
uniform float reveal;           // By hand: 0 hidden, 1 shown (a fader, MIDI)
//@int min=1 max=64 value=8
uniform int loop_beats;         // Loop: one reveal and hide in this many beats
//@slider min=0.0 max=1.0 value=0.3
uniform float hold;             // Loop: share of the loop that stays fully shown
//@slider min=0.0 max=0.5 value=0.08
uniform float wipe_softness;
//@slider min=-180.0 max=180.0 value=0.0
uniform float wipe_angle;       // Linear: degrees
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 wipe_center;       // Radial
//@slider min=4.0 max=600.0 value=90.0
uniform float wipe_depth;       // From the outlines / From the middle: pixels the wipe runs into a surface
//@slider min=0.5 max=20.0 value=4.0
uniform float noise_scale;
//@slider min=-60.0 max=60.0 value=0.0
uniform float grow;             // pixels: grows (shrinks when negative) the surfaces
//@slider min=0.0 max=60.0 value=2.0
uniform float feather;          // pixels: the soft edge of the cut
//@slider min=0.0 max=0.3 value=0.04
uniform float front_width;      // the bright front of the wipe
//@slider min=0.0 max=4.0 value=1.2
uniform float front_glow;
//@rgb value=(1.0, 0.85, 0.6)
uniform vec3 front_color;
//@slider min=0.0 max=20.0 value=0.0
uniform float outline_width;    // pixels: a line along the outline of the surfaces
//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 outline_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float outside_level;    // the input outside the surfaces (0: black)
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;        // calibration: the mask in red over the picture

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    vec2 n;
    float sd = jfa_signed(J10, M, fragCoord, n) - grow;
    float f = max(feather, 0.5);
    float cover = 1.0 - smoothstep(-f * 0.5, f * 0.5, sd);

    // the progress of the wipe
    float p = reveal;
    vec3 pl = mp_pulse(T);
    if (drive == 1) {
        float t = fract(iTime / float(max(loop_beats, 1)));
        float h = clamp(hold, 0.0, 0.9);
        float ramp = (1.0 - h) * 0.5;
        p = t < ramp ? t / ramp : (t < ramp + h ? 1.0 : 1.0 - (t - ramp - h) / ramp);
    } else if (drive == 2) {
        p = 1.0 - pl.x;
    }

    // where this pixel is on the way of the wipe (0 first, 1 last)
    float a = iResolution.x / iResolution.y;
    float w = 0.5;
    if (wipe == 1) {
        vec2 dir = vec2(cos(radians(wipe_angle)), sin(radians(wipe_angle)));
        float he = 0.5 * (abs(dir.x) * a + abs(dir.y));
        w = dot((uv - 0.5) * vec2(a, 1.0), dir) / (2.0 * he) + 0.5;
    } else if (wipe == 2) {
        vec2 far = max(wipe_center, 1.0 - wipe_center) * vec2(a, 1.0);
        w = length((uv - wipe_center) * vec2(a, 1.0)) / max(length(far), 0.01);
    } else if (wipe == 3) {
        w = clamp(-sd / max(wipe_depth, 1.0), 0.0, 1.0);
    } else if (wipe == 4) {
        w = 1.0 - clamp(-sd / max(wipe_depth, 1.0), 0.0, 1.0);
    } else if (wipe == 5) {
        vec2 q = uv * vec2(a, 1.0) * noise_scale;
        w = clamp((mp_vnoise(q) * 0.6 + mp_vnoise(q * 2.3 + 7.0) * 0.3 + mp_vnoise(q * 5.1 + 3.0) * 0.1 - 0.15) * 1.4, 0.0, 1.0);
    }
    float s = max(wipe_softness, 0.001);
    float pe = p * (1.0 + 2.0 * s) - s;   // so 0 hides and 1 shows everything
    float shown = wipe == 0 ? p : 1.0 - smoothstep(pe - s, pe + s, w);
    float front = (wipe == 0 || p <= 0.0 || p >= 1.0) ? 0.0 : exp(-abs(w - pe) / max(front_width, 0.002)) * front_glow;

    vec3 rgb = src.rgb * outside_level * (1.0 - cover);
    rgb += (src.rgb * shown + front_color * front) * cover;
    if (outline_width > 0.0) {
        float ol = 1.0 - smoothstep(outline_width * 0.5 - 0.75, outline_width * 0.5 + 0.75, abs(sd));
        rgb = mix(rgb, outline_color, ol);
    }
    float alpha = max(cover, outside_level * src.a);   // transparent outside the surfaces, for layers
    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * mp_bilinear_uv(M, uv).r);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
