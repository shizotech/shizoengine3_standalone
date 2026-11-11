//@settings dtype=float32 format=rgba
// --- MaskReaction (#586, projection mapping building blocks: simulations in the mask) ---
// Reaction and diffusion in three models: Gray-Scott (coral, mitosis, worms, mazes, spots, U-skate, holes, chaos or
// your own feed and kill), FitzHugh-Nagumo (waves and spirals of an excitable medium, in Barkley's form) and the BZ
// reaction (Alasdair Turner's three chemicals). Eight steps a frame at half the size (S1..S8; S1 also starts, restarts
// and seeds). The mask is a parameter map (one pattern inside the white shapes, another around them) or a wall the
// patterns line up along (pass M). H turns the chemicals into a height field that lib/relief.glsl renders like wax,
// wet tissue, metal or jelly, with shadows and bloom (L, R, B1..B3), or flat.
#define PASS_SCALE 1.0
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D R;
uniform sampler2D B3;
uniform sampler2D H;
uniform sampler2D M;
uniform sampler2D S8;

//@enum options=(Pattern, Black, Colour, Outline, Transparent) value=0
uniform int wall_view;         // what the walls show (Inside only / Outside only): Pattern keeps the picture as it is
//@rgb value=(0.12, 0.12, 0.15)
uniform vec3 wall_color;
//@enum options=(Final, Height, Normals, Chemicals, Mask) value=0
uniform int debug_view;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;       // calibration: the mask in red over the picture

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 r = texelFetch(R, ivec2(fragCoord), 0);
    vec3 bl = mp_bilinear_uv(B3, uv).rgb;
    vec3 rgb = rl_finish(r.rgb, bl, fragCoord);
    float alpha = r.a;

    if (debug_view == 1) {
        rgb = vec3(mp_bilinear_uv(H, uv).r);
    } else if (debug_view == 2) {
        vec3 hg = rl_height_grad(H, uv);
        vec2 sl = hg.yz * vec2(textureSize(H, 0)) / iResolution.y * relief_height * 0.5;
        rgb = normalize(vec3(-sl, 1.0)) * 0.5 + 0.5;
    } else if (debug_view == 3) {
        vec4 s = mp_bilinear_uv(S8, uv);
        rgb = model == 0 ? vec3(s.x, s.y * 2.0, 0.0) : s.rgb;
    } else if (debug_view == 4) {
        vec4 m = mp_bilinear_uv(M, uv);
        rgb = vec3(m.r * 0.5, m.g * 0.6, m.b);
    }
    if (debug_view != 0) alpha = 1.0;

    // the walls and the mask at full size from pass M (in the main pass the port Mask may read another texture, #880)
    vec2 guv = rl_ground_uv(uv);   // with Camera tilt the mask lies on the tilted ground
    vec4 mm = rl_smooth(M, guv);
    if (guv.x < 0.0 || guv.y < 0.0 || guv.x > 1.0 || guv.y > 1.0) mm = vec4(0.0, 0.0, 0.0, mm.a);
    float w = 0.0;
    if (mm.a < 3.5 && mask_role == 1) w = 1.0 - smoothstep(0.35, 0.65, mm.r);   // the mask's own soft edge
    else if (mm.a < 3.5 && mask_role == 2) w = smoothstep(0.35, 0.65, mm.r);
    if (debug_view == 0) {
        if (wall_view == 1) rgb *= 1.0 - w;
        else if (wall_view == 2) rgb = mix(rgb, wall_color, w);
        else if (wall_view == 3) {
            float line = clamp(1.0 - abs(w - 0.5) * 2.5, 0.0, 1.0);
            rgb = mix(rgb * (1.0 - w), wall_color * 4.0, line);
        } else if (wall_view == 4) alpha *= 1.0 - w;
    }
    if (show_mask > 0.0) {
        float m = mm.a > 3.5 ? 0.0 : smoothstep(0.3, 0.7, mm.r);
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
