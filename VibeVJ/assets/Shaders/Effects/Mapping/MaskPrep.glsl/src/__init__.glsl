//@settings dtype=float32 format=rgba
// --- MaskPrep (#586, projection mapping building blocks) ---
// Makes a clean mask of any picture once, for every other asset that takes a mask: a PNG traced over a photo, the
// output of MapLab, a camera. Channel, threshold, blur, invert and the calibration (move, scale, turn) as in every
// asset of the set, then grow / shrink and a soft edge in pixels (from a jump flood at half size, passes M, E,
// J1..J10). Out: the mask, the mask as alpha, its outline, a check over the input, or the distance field.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D J10;

//@enum options=(Mask, Mask as alpha, Outline, Check over the input, Distance field) value=0
uniform int output_mode;
//@slider min=-80.0 max=80.0 value=0.0
uniform float grow;             // pixels: grows (shrinks when negative) the white parts
//@slider min=0.0 max=80.0 value=1.0
uniform float feather;          // pixels: the soft edge
//@slider min=0.5 max=30.0 value=3.0
uniform float outline_width;    // pixels (Outline, Check over the input)
//@slider min=4.0 max=1000.0 value=120.0
uniform float distance_range;   // Distance field: pixels from black to white (grey 0.5 is the outline)
//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 mask_color;        // the colour of the white parts (Mask, Mask as alpha, Outline)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 n;
    float sd = jfa_signed(J10, M, fragCoord, n) - grow;
    float f = max(feather, 0.5);
    float cover = 1.0 - smoothstep(-f * 0.5, f * 0.5, sd);
    float ol = 1.0 - smoothstep(outline_width * 0.5 - 0.75, outline_width * 0.5 + 0.75, abs(sd));

    vec3 rgb;
    float alpha = 1.0;
    if (output_mode == 1) {
        rgb = mask_color;
        alpha = cover;
    } else if (output_mode == 2) {
        rgb = mask_color * ol;
    } else if (output_mode == 3) {
        vec3 src = texture(input, uv).rgb;
        rgb = mix(src * 0.6, vec3(1.0, 0.15, 0.1), cover * 0.4);
        rgb = mix(rgb, vec3(1.0, 0.9, 0.1), ol);
    } else if (output_mode == 4) {
        rgb = vec3(clamp(0.5 - sd / max(distance_range, 1.0) * 0.5, 0.0, 1.0));
    } else {
        rgb = mask_color * cover;
    }
    fragColor = vec4(rgb, alpha);
}
