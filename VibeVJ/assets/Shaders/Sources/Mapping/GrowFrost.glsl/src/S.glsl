//@settings dtype=float32 format=rgba rendersize=(4,1)
// --- GrowFrost, pass S: the life cycle (lib/growth.glsl). Counts the share of the soil that is ice at 24 x 24 places
// (new ones every frame, smoothed) and turns when it is full ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D T;
uniform sampler2D M;
uniform sampler2D F6;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gr_load(feedback);
    vec2 rres = vec2(textureSize(F6, 0));
    vec2 mres = vec2(textureSize(M, 0));
    float grown = 0.0;
    float area = 0.0;
    for (int i = 0; i < 576; i++) {
        vec2 uv = gr_sample_uv(i, 24);
        if (texelFetch(M, ivec2(uv * mres), 0).r < 0.5) continue;
        area += 1.0;
        vec4 f = texelFetch(F6, ivec2(uv * rres), 0);
        if (f.x > 0.5 && gr_decay(f.z, uv) < 0.9) grown += 1.0;
    }
    fragColor = gr_state_pass(feedback, T, ivec2(fragCoord), area > 0.5 ? grown / area : 0.0);
}
