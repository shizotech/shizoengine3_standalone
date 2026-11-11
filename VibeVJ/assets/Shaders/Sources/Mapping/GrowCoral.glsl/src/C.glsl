//@settings dtype=float32 format=rgba renderscale=0.5
// --- GrowCoral, pass C: the look of each cell for the colours (lib/growth.glsl, gr_look): its age, how far it died in a
// turn, its generation, its variation. The picture reads it bilinear, so the colours are smooth at full size ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D R6;
uniform sampler2D S;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(S);
    vec2 uv = fragCoord / iResolution.xy;
    vec4 c = texelFetch(R6, ivec2(fragCoord), 0);
    fragColor = gr_look(c.z, c.w, uv);
}
