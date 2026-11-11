//@settings dtype=float32 format=rgba
// --- MaskPhysarum, pass R: the slime lit at full size, in linear light (rl_render in lib/relief.glsl), and with
// Show agents every agent as a tiny bright dot on it (#892) ---
#include lib/common.glsl
#include lib/relief.glsl

uniform sampler2D H;
uniform sampler2D L;
uniform sampler2D T;
uniform sampler2D Y2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = rl_render(H, L, mp_pulse(T), fragCoord);
    if (show_agents > 0.0) {
        // the agents of the 3 x 3 cells around the place this pixel shows, each a Gaussian dot about a pixel wide
        ivec2 g = textureSize(Y2, 0);
        vec2 gp = rl_hit * vec2(g);
        ivec2 c0 = ivec2(floor(gp));
        float cells_per_px = float(g.y) / iResolution.y * max(camera_zoom, 0.05);
        vec3 dots = vec3(0.0);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                ivec2 q = c0 + ivec2(x, y);
                if (q.x < 0 || q.y < 0 || q.x >= g.x || q.y >= g.y) continue;
                Agent a = ph_decode(texelFetch(Y2, q, 0));
                if (!a.alive) continue;
                vec2 d = (gp - vec2(q) - a.frac) / cells_per_px;
                dots += srgbToLinear(ph_strain_color(a.strain)) * exp(-dot(d, d) * 1.2);
            }
        }
        fragColor.rgb += dots * show_agents * 2.5;
        fragColor.a = max(fragColor.a, clamp(max(dots.r, max(dots.g, dots.b)) * show_agents * 2.5, 0.0, 1.0));
    }
}
