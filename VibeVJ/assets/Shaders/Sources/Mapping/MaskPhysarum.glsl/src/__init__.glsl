//@settings dtype=float32 format=rgba
// --- MaskPhysarum (#586, projection mapping building blocks: simulations in the mask) ---
// Physarum polycephalum, the yellow slime mould, as Jeff Jones's agent model (2010): up to a few 100 000 agents at half the
// size (one per cell at most) smell a trail three times ahead, turn towards the strongest smell, step and leave trail;
// the trail spreads and fades. Two steps a frame: X1/Y1, X2/Y2 (sense and spread, then step: a cell takes the agent
// with the highest priority, lib/common.glsl), C counts the agents. The mask is food (the slime grows a transport
// network between the objects), a wall or a container (pass M). Up to 8 strains, each with its own colour and a
// little different way to move, keep to their own kind and compete (#892). H turns the trail into a height field that
// lib/relief.glsl renders as wet, glossy slime with subsurface light, shadows and bloom (L, R, B1..B3), or flat.
#define PASS_SCALE 1.0
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D R;
uniform sampler2D B3;
uniform sampler2D H;
uniform sampler2D M;
uniform sampler2D Y2;

//@enum options=(Black, Colour, Outline, Transparent, Slime over it) value=0
uniform int obstacle_view;     // what the walls of the mask show: on a real object Black keeps it dark
//@rgb value=(0.12, 0.12, 0.15)
uniform vec3 obstacle_color;
//@enum options=(Final, Height, Normals, Trail, Agents, Food and walls) value=0
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
        // the trail, white where the strains mix, in the colour of a strain where it is alone; a hole (Repel) blue
        vec4 s = mp_bilinear_uv(Y2, uv);
        float full = max(deposit, 0.05) / max(decay, 0.005);
        vec3 hue = mix(vec3(1.0), ph_palette(atan(s.b, s.g) / MP_TAU), clamp(length(s.gb) / max(s.r, 1e-4), 0.0, 1.0));
        rgb = (s.r > 0.0 ? hue * s.r : vec3(0.0, 0.0, -s.r)) / full * 2.0;
    } else if (debug_view == 4) {
        ivec2 c = ivec2(uv * vec2(textureSize(Y2, 0)));
        Agent a = ph_decode(texelFetch(Y2, c, 0));
        rgb = a.alive ? ph_strain_color(a.strain) * (0.6 + 0.4 * cos(a.heading)) : vec3(0.0);
    } else if (debug_view == 5) {
        vec4 m = mp_bilinear_uv(M, uv);
        rgb = vec3(m.b * 0.6, m.g, m.r * 0.3);
    }
    if (debug_view != 0) alpha = 1.0;

    // the walls of the mask at full size (from pass M: in the main pass the port Mask may read another texture, #880)
    vec2 guv = rl_ground_uv(uv);   // with Camera tilt the mask lies on the tilted ground
    vec4 mm = rl_smooth(M, guv);
    if (guv.x < 0.0 || guv.y < 0.0 || guv.x > 1.0 || guv.y > 1.0) mm = vec4(0.0, 0.0, 0.0, mm.a);
    float w = smoothstep(0.3, 0.7, mm.b);
    if (mask_role == 0 || mask_role == 2) w = smoothstep(0.35, 0.65, mm.r);   // the mask's own soft edge
    else if (mask_role == 3 && mm.a < 3.5) w = 1.0 - smoothstep(0.35, 0.65, mm.r);
    if (debug_view == 0) {
        if (obstacle_view == 0) rgb *= 1.0 - w;
        else if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, w);
        else if (obstacle_view == 2) {
            float line = clamp(1.0 - abs(w - 0.5) * 2.5, 0.0, 1.0);
            rgb = mix(rgb * (1.0 - w), obstacle_color * 4.0, line);
        } else if (obstacle_view == 3) alpha *= 1.0 - w;
    }
    if (show_mask > 0.0) {
        float m = smoothstep(0.3, 0.7, mm.r);
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
