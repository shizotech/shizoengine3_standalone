//@settings dtype=float32 format=rgba
// --- MaskBeams (#586, projection mapping building blocks: simulations in the mask) ---
// Laser beams that bounce off the mapped objects: the white shapes of the mask are mirrors, glass (beams bend, prisms
// split them into colours with Dispersion) or absorbers (a hot spot where a beam hits). Up to eight beams from emitters
// in a row, at the sides, in the corners, from the middle or from a point, that sweep, turn, wander or jump to new
// angles at a pulse. Pass B traces each beam through the distance field of the mask (a jump flood at half size,
// passes M, E, J1..J10), pass G draws their light in a drifting haze.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D G;
uniform sampler2D M;
uniform sampler2D J10;

//@slider min=0.0 max=3.0 value=1.0
uniform float brightness;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Outline, Transparent, Beams over it) value=2
uniform int obstacle_view;    // what the white shapes show: Outline draws their edges, faintly lit by the beams
//@rgb value=(0.15, 0.2, 0.25)
uniform vec3 obstacle_color;
//@enum options=(Final, Distance field) value=0
uniform int debug_view;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 light = mp_bilinear_uv(G, uv).rgb * brightness;
    // a soft shoulder instead of a hard clip, so crossing beams stay coloured
    light = light / (1.0 + max(max(light.r, light.g), light.b) * 0.25);
    vec3 rgb = background + light;

    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = smoothstep(0.35, 0.65, mp_bilinear_uv(M, uv).r);
    if (mp_mask_mode() == 4) m = 0.0;
    float alpha = 1.0;
    if (obstacle_view == 0) rgb *= 1.0 - m;
    else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, m);
    else if (obstacle_view == 2) {
        vec2 n;
        float sd = jfa_signed(J10, M, fragCoord, n);
        float line = 1.0 - smoothstep(0.8, 2.0, abs(sd));
        vec3 lit = mp_bilinear_uv(G, uv).rgb;
        rgb = mix(rgb * (1.0 - m * (surfaces == 1 ? 0.3 : 0.85)), obstacle_color + lit * 0.6, line);
    } else if (obstacle_view == 3) alpha = 1.0 - m;

    if (debug_view == 1) {
        vec2 n;
        float sd = jfa_signed(J10, M, fragCoord, n);
        rgb = vec3(0.5 + 0.5 * sin(sd * 0.2)) * (sd < 0.0 ? vec3(1.0, 0.4, 0.3) : vec3(0.4, 0.8, 1.0)) + light;
    }
    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
