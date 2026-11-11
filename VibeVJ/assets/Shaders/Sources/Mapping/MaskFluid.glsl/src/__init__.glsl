//@settings dtype=float32 format=rgba
// --- MaskFluid (#586, projection mapping building blocks) ---
// Smoke or liquid that flows around and between the white shapes of a mask (or stays inside them): a stable-fluids
// simulation on a quarter of the size (passes M, U, D, P1..P8, Q: walls, forces and advection, divergence, eight
// Jacobi steps of the pressure that start from the last frame's, projection) and the smoke on half the size (Y).
// Jets, the outlines of the mask, a picture and the pulses of the beat add smoke and push the flow.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D Y;
uniform sampler2D Q;
uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl

//@enum options=(Smoke, Liquid, Glow, Velocity) value=0
uniform int look;
//@slider min=0.1 max=8.0 value=1.6
uniform float density_gain;
//@slider min=0.05 max=1.0 value=0.3
uniform float liquid_level;    // Liquid: how much smoke makes a surface
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Outline, Transparent, Smoke over it) value=0
uniform int obstacle_view;     // what the walls show: on a real object Black keeps it dark, so only the space between is lit
//@rgb value=(0.15, 0.15, 0.2)
uniform vec3 obstacle_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;       // calibration: the mask in red over the picture

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    vec2 uv = fragCoord / iResolution.xy;
    vec2 yres = vec2(textureSize(Y, 0));
    vec4 dye = mp_bilinear(Y, uv * yres);
    float dens = max(dye.a, 0.0);
    vec3 col = dye.rgb / max(dens, 1e-3);
    col = clamp(col, 0.0, 2.0);

    vec3 rgb = background;
    if (look == 1) {
        // a surface where the density passes the level, lit from the top left
        float e = 1.0;
        float dx = mp_bilinear(Y, uv * yres + vec2(e, 0.0)).a - mp_bilinear(Y, uv * yres - vec2(e, 0.0)).a;
        float dy = mp_bilinear(Y, uv * yres + vec2(0.0, e)).a - mp_bilinear(Y, uv * yres - vec2(0.0, e)).a;
        vec3 n = normalize(vec3(-dx, -dy, 0.35));
        vec3 l = normalize(vec3(-0.5, 0.6, 0.7));
        float lv = dens * density_gain * 0.5;
        float f = smoothstep(liquid_level - 0.04, liquid_level + 0.04, lv);
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0), 40.0);
        float depth = 1.0 - exp(-lv * 2.0);
        vec3 liquid = col * (0.25 + 0.75 * diff) * (0.6 + 0.4 * depth) + vec3(spec * 0.9);
        rgb = mix(background, liquid, f);
    } else if (look == 2) {
        rgb = background + col * dens * density_gain * 0.6;
    } else if (look == 3) {
        vec2 v = mp_bilinear_uv(Q, uv).xy;
        float sp = length(v);
        rgb = mp_hue(atan(v.y, v.x) / MP_TAU + 0.5) * clamp(sp * 0.6, 0.0, 1.0);
    } else {
        float a = 1.0 - exp(-dens * density_gain);
        rgb = mix(background, col, a);
    }

    // the walls at full size: the mask again (without blur), or the simulation's when it is blurred
    float s = mask_blur < 0.25 ? fl_solid_raw(uv) : mp_bilinear_uv(M, uv).r;
    float alpha = 1.0;
    if (obstacle_view == 0) rgb *= 1.0 - s;
    else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, s);
    else if (obstacle_view == 2) {
        float w = fwidth(s);
        float line = clamp(1.0 - abs(s - 0.5) * 2.0, 0.0, 1.0);
        line = max(line, smoothstep(0.0, 1.0, w * 2.0));
        rgb = mix(rgb * (1.0 - s), obstacle_color * 4.0, line);
    } else if (obstacle_view == 3) alpha = 1.0 - s;

    if (show_mask > 0.0) {
        float m = mp_mask(uv);
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
