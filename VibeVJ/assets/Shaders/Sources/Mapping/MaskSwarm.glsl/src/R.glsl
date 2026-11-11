//@settings dtype=float32 format=rgba renderscale=0.5
// --- MaskSwarm, pass R: the trails at half size. The last frame fades by Trails, every boid adds a soft dot ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D B;

//@slider min=0.0 max=0.99 value=0.85
uniform float trails;         // how long the trails stay: 0 none
//@slider min=0.0 max=2.0 value=0.35
uniform float trail_brightness;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 last = (iFrame < 2 || textureSize(feedback, 0) != ivec2(iResolution.xy)) ? vec4(0.0)
              : texelFetch(feedback, ivec2(fragCoord), 0);
    ivec2 grid = textureSize(B, 0);
    float cell = iResolution.x / float(grid.x);       // texels of this pass in a cell
    vec2 gp = fragCoord / cell;
    ivec2 c0 = ivec2(floor(gp));
    vec3 add = vec3(0.0);
    if (trails > 0.0) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                ivec2 n = c0 + ivec2(x, y);
                if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y) continue;
                Boid b = sw_decode(texelFetch(B, n, 0));
                if (!b.alive) continue;
                vec2 d = (gp - b.pos) * cell;
                add += sw_color(b, speed) * exp(-dot(d, d) / 1.2);
            }
        }
    }
    vec3 rgb = last.rgb * trails + add * trail_brightness * (1.0 - trails) * 2.0;
    fragColor = vec4(min(rgb, vec3(4.0)), 1.0);
}
