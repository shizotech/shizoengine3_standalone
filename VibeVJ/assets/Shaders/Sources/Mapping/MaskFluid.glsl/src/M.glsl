//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFluid, pass M: the walls of the simulation grid (a quarter of the size). r: wall 0..1, gb: the direction
// out of the wall into the free space, a: how much this texel is an outline ---
#define PASS_SCALE 0.25
#include lib/common.glsl

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;
    float s = fl_solid_raw(uv);
    float l = fl_solid_raw(uv - vec2(px.x, 0.0));
    float r = fl_solid_raw(uv + vec2(px.x, 0.0));
    float d = fl_solid_raw(uv - vec2(0.0, px.y));
    float u = fl_solid_raw(uv + vec2(0.0, px.y));
    vec2 g = vec2(l - r, d - u) * 0.5;
    float gl = length(g);
    vec2 n = gl > 1e-4 ? g / gl : vec2(0.0);
    fragColor = vec4(s, n, clamp(gl * 2.0, 0.0, 1.0));
}
