//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskSand, pass A: the first step of the automaton in a frame (blocks from cell 0), then the new grains from the
// spouts, the top edge and a picture. Reads B, the second step of the last frame ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D B;
uniform sampler2D M;
uniform sampler2D T;
uniform sampler2D I;          // is a picture linked (pass I): not textureSize() here, this pass has other inputs (#880)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    sd_picture_linked = texelFetch(I, ivec2(0, 0), 0).r > 0.5;
    ivec2 size = ivec2(iResolution.xy);
    ivec2 p = ivec2(fragCoord);
    if (iFrame < 2 || textureSize(B, 0) != size || clear_now) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 pl = mp_pulse(T);
    float shake = pulse_action == 2 ? pulse_amount * pl.x : 0.0;
    bool floor_open = ground == 1 || (pulse_action == 3 && pl.x > 0.3 * (1.0 - pulse_amount) + 0.05);
    float clear_rate = pulse_action == 4 ? pulse_amount * pl.x * 0.12 : 0.0;
    vec4 c = sd_step(B, M, p, 0, uint(iFrame) * 2u, shake, floor_open, clear_rate);
    if (sd_solid_of(texelFetch(M, p, 0).r)) {
        fragColor = vec4(0.0);
        return;
    }

    uint h = mp_hash(uint(p.x) * 73856093u ^ uint(p.y) * 19349663u ^ uint(iFrame) * 83492791u);
    float r1 = mp_rand(h);
    float r2 = mp_rand(h + 1u);
    vec2 uv = fragCoord / iResolution.xy;
    if (c.a < 0.5) {
        // the spouts along the top
        float n = float(max(spouts, 1));
        float wcells = max(spout_width * PASS_SCALE, 1.0);
        float burst = pulse_action == 0 ? 1.0 + 6.0 * pulse_amount * pl.x : 1.0;
        for (int k = 0; k < 12; k++) {
            if (k >= spouts) break;
            float fk = float(k);
            float x = (fk + 0.5) / n + spout_wander * (mp_vnoise(vec2(fk * 7.7 + 1.0, iTime * 0.08)) - 0.5) * 1.6 / n;
            x = clamp(x, 0.02, 0.98) * iResolution.x;
            if (abs(fragCoord.x - x) < wcells * 0.5 && p.y >= size.y - 2 && r1 < pour * burst * 0.5) {
                int kind = material == 1 ? 2 : (material == 2 && k % 2 == 1 ? 2 : 1);
                c = vec4(sd_new_color(uv, k, r2), float(kind) + 4.0);
            }
        }
        if (p.y == size.y - 1 && r1 < snow * burst) c = vec4(sd_new_color(uv, -1, r2), material == 1 ? 6.0 : 5.0);
        // a picture falls apart into grains
        if (pulse_action == 1 && pl.z > 0.5) {
            bool linked = sd_picture_linked;
            vec3 pc = linked ? texture(picture, uv).rgb : vec3(0.0);
            float on = linked ? step(0.2, max(pc.r, max(pc.g, pc.b))) : step(0.75, uv.y) * step(r1, 0.6);
            if (on > 0.5 && r2 < pulse_amount + 0.2) c = vec4(linked ? pc : sd_new_color(uv, -1, r2), material == 1 ? 6.0 : 5.0);
        }
    }
    if (ground == 0 && p.y == 0 && c.a > 0.5 && r1 < drain) c = vec4(0.0);
    fragColor = c;
}
