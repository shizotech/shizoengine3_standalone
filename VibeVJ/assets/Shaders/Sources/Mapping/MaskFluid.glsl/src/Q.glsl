//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFluid, pass Q: the velocity without divergence (U minus the gradient of the pressure of P8): the flow
// goes around the walls instead of into them. b keeps the pressure, the start of the next frame's solve ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D U;
uniform sampler2D P8;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    if (texelFetch(M, p, 0).r > 0.5) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    float pc = texelFetch(P8, p, 0).r;
    float pl = fl_pressure(P8, 0, M, p - ivec2(1, 0), pc);
    float pr = fl_pressure(P8, 0, M, p + ivec2(1, 0), pc);
    float pd = fl_pressure(P8, 0, M, p - ivec2(0, 1), pc);
    float pu = fl_pressure(P8, 0, M, p + ivec2(0, 1), pc);
    vec2 v = texelFetch(U, p, 0).xy - 0.5 * vec2(pr - pl, pu - pd);
    v = fl_walls(M, p, v);
    fragColor = vec4(v, pc, 1.0);
}
