//@settings dtype=float32 format=rgba
// --- Datamosh, pass P: the input of this frame and of the last one, packed: (now, before, brightness now, before) ---
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 now = texture(input, fragCoord / iResolution.xy).rgb;
    vec4 last = stateOr(texelFetch(feedback, ivec2(fragCoord), 0), vec4(0.0));
    float pNow = packColor(now);
    if (iFrame < 2)
        last = vec4(pNow, pNow, lumaOf(now), lumaOf(now));
    fragColor = vec4(pNow, last.x, lumaOf(now), last.z);
}
