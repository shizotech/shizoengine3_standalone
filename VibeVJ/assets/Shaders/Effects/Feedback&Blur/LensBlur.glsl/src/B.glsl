//@settings dtype=float16 format=rgba renderscale=0.25
// --- LensBlur, pass B: the bokeh, gathered at a quarter of the size on a golden-angle spiral ---
// The colours of P are averaged. The highlights of Q are averaged as a power mean (p = 4) too: one bright point among
// many dark taps still gives a bright disc, as a light does in a real lens, although the picture has no values
// above 1. What the power mean has more than the plain mean is added (Highlight gain).
#include lib/common.glsl

uniform sampler2D P;
uniform sampler2D Q;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 center = sampleLinear(P, uv);
    float rmax = maxRadiusPx();
    if (rmax < 0.5) {
        fragColor = vec4(center.rgb, 1.0);
        return;
    }
    int n = tapCount();
    vec3 hc = sampleLinear(Q, uv).rgb;
    vec3 sum = center.rgb;
    vec3 hlSum = hc;
    vec3 hlPow = pow(hc, vec3(4.0));
    float wsum = 1.0;
    for (int i = 0; i < 128; i++) {
        if (i >= n)
            break;
        float rn = sqrt((float(i) + 0.5) / float(n));          // 0 .. 1, even over the disc
        float a = float(i) * GOLDEN_ANGLE;
        float r = rn * rmax * bladeShape(a);
        vec2 at = uv + vec2(cos(a), sin(a)) * r / iResolution.xy;
        vec4 s = sampleLinear(P, at);
        // the disc of that point (its own size) must reach this pixel
        float w = smoothstep(r - 1.0, r + 1.0, s.a * rmax + 0.5);
        w *= 1.0 + ring * smoothstep(0.65, 1.0, rn);
        vec3 hl = sampleLinear(Q, at).rgb;
        sum += s.rgb * w;
        hlSum += hl * w;
        hlPow += pow(hl, vec3(4.0)) * w;
        wsum += w;
    }
    vec3 avg = sum / wsum;
    vec3 pmean = pow(hlPow / wsum, vec3(0.25));
    fragColor = vec4(avg + highlight_gain * max(pmean - hlSum / wsum, 0.0), 1.0);
}
