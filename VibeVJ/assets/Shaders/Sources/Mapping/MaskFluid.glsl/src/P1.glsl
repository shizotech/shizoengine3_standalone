//@settings dtype=float32 format=rgba renderscale=0.25
// --- MaskFluid, pass P1: Jacobi step 1 of 8 of the pressure, starts from the pressure of the last frame (Q.b). Next to a wall the pressure of the
// texel itself (nothing flows through), outside an open border 0 ---
#define PASS_SCALE 0.25
#include lib/common.glsl

uniform sampler2D Q;
uniform sampler2D D;
uniform sampler2D M;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    if (texelFetch(M, p, 0).r > 0.5) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    float pc = texelFetch(Q, p, 0)[2] * 0.995;
    float s = fl_pressure(Q, 2, M, p - ivec2(1, 0), pc) + fl_pressure(Q, 2, M, p + ivec2(1, 0), pc)
            + fl_pressure(Q, 2, M, p - ivec2(0, 1), pc) + fl_pressure(Q, 2, M, p + ivec2(0, 1), pc);
    fragColor = vec4((s - texelFetch(D, p, 0).r) * 0.25, 0.0, 0.0, 1.0);
}
