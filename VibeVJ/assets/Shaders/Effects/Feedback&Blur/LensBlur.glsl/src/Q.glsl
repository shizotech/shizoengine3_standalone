//@settings dtype=float16 format=rgba renderscale=0.25
// --- LensBlur, pass Q: the highlights of H grown by about half the distance between two taps of B ---
// Without it a small light is hit by some taps of a pixel and missed by those of its neighbour: its disc would be
// speckled instead of even.
#include lib/common.glsl

uniform sampler2D H;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 c = ivec2(floor(fragCoord));
    ivec2 hi = textureSize(H, 0) - 1;
    float r = clamp(0.8 * tapSpacing(), 1.0, 5.0);
    int ri = int(ceil(r));
    vec3 best = vec3(0.0);
    float bestL = 0.0;
    for (int y = -5; y <= 5; y++) {
        if (abs(y) > ri)
            continue;
        for (int x = -5; x <= 5; x++) {
            if (abs(x) > ri)
                continue;
            // a soft edge: the grown light fades out towards r, so the discs get round, even edges
            float fall = 1.0 - smoothstep(0.4 * r, r + 0.5, length(vec2(x, y)));
            vec3 h = texelFetch(H, clamp(c + ivec2(x, y), ivec2(0), hi), 0).rgb * fall;
            float l = luminance(h);
            if (l > bestL) {
                bestL = l;
                best = h;
            }
        }
    }
    fragColor = vec4(best, 1.0);
}
