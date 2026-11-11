//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFire, pass K: the embers on a grid of cells at a quarter of the size, one ember a cell at most. A cell keeps
// the ember that moves into it: r, g its place (cells), b its age (frames), a its seed (1..2); a = 0 empty ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D H;
uniform sampler2D M;
uniform sampler2D T;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 grid = ivec2(iResolution.xy);
    ivec2 c = ivec2(floor(fragCoord));
    if (iFrame < 2 || textureSize(feedback, 0) != grid) {
        fragColor = vec4(0.0);
        return;
    }
    // the ember that moved into this cell (the oldest, if two did)
    vec4 best = vec4(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 n = c + ivec2(x, y);
            if (n.x < 0 || n.y < 0 || n.x >= grid.x || n.y >= grid.y) continue;
            vec4 e = texelFetch(feedback, n, 0);
            if (e.a < 0.5 || ivec2(floor(e.xy)) != c) continue;
            if (best.a < 0.5 || e.b > best.b) best = e;
        }
    }
    vec2 uv = (vec2(c) + 0.5) / vec2(grid);
    vec3 pl = mp_pulse(T);
    uint h0 = mp_hash(uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(iFrame) * 83492791u);
    float r1 = mp_rand(h0);
    float r2 = mp_rand(h0 + 1u);
    float r3 = mp_rand(h0 + 2u);
    if (best.a > 0.5) {
        best.b += 1.0;
        float life = (40.0 + 110.0 * (best.a - 1.0)) * ember_life;
        if (best.b > life || fr_wall_of(mp_bilinear_uv(M, uv).r) > 0.5) {
            fragColor = vec4(0.0);
            return;
        }
    } else {
        float heat = mp_bilinear_uv(H, uv).r;
        float chance = embers * 0.00018 * max(heat - 0.5, 0.0);
        if ((pulse_action == 1 || pulse_action == 2) && pl.z > 0.5) chance += pulse_amount * 0.005 * step(0.4, heat);
        if (r1 >= chance) {
            fragColor = vec4(0.0);
            return;
        }
        best = vec4(vec2(c) + 0.1 + 0.8 * vec2(r2, r3), 0.0, 1.0 + mp_rand(h0 + 3u));
    }
    // carried by the flow, faster than the flames, with a wobble of its own
    vec2 v = fr_velocity(M, best.xy / vec2(grid)) * PASS_SCALE * 1.2;
    v.x += sin(best.b * 0.15 + best.a * 40.0) * 0.18;
    v.y += 0.1;
    float sp = length(v);
    if (sp > 0.95) v *= 0.95 / sp;
    best.xy += v;
    fragColor = best;
}
