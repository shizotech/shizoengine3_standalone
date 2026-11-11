//@settings dtype=float32 format=rgba rendersize=(4,1)
// --- GrowBranches, pass S: the life cycle (lib/growth.glsl). Counts the share of the soil that is near a branch (closer than Spacing) at 24 x 24 places
// (new ones every frame, smoothed) and turns when it is full ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D T;
uniform sampler2D M;
uniform sampler2D J10;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(feedback);
    vec2 rres = vec2(textureSize(J10, 0));
    vec2 mres = vec2(textureSize(M, 0));
    float grown = 0.0;
    float area = 0.0;
    for (int i = 0; i < 576; i++) {
        vec2 uv = gr_sample_uv(i, 24);
        if (texelFetch(M, ivec2(uv * mres), 0).r < 0.5) continue;
        area += 1.0;
        vec4 j = texelFetch(J10, ivec2(uv * rres), 0);
        if (j.w > 0.5 && length(j.xy - uv * rres) < spacing * 0.5) grown += 1.0;
    }
    fragColor = gr_state_pass(feedback, T, ivec2(fragCoord), area > 0.5 ? grown / area : 0.0);
}
