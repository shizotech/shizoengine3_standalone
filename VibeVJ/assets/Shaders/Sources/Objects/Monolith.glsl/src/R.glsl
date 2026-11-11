//@settings dtype=float16 format=rgba renderscale=0.25
// --- pass R: the light rays. The bright parts (pass B) smeared outwards from the middle of the object (a radial
// blur, so the dark faces cut shadows into the light), broken into beams that turn slowly ---
#include lib/common.glsl

uniform sampler2D B;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    if (rays <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    float aspect = iResolution.x / iResolution.y;
    vec2 c = objectOnScreen(iTime, iResolution.xy);
    vec2 dir = uv - c;
    int n = quality == 1 ? 24 : 40;
    // every sample a little further towards the middle; a random start per pixel hides the steps
    vec2 stp = dir * mix(0.25, 0.97, ray_length) / float(n);
    float decay = mix(0.86, 0.985, ray_length);
    vec2 p = uv - stp * hash12(fragCoord + float(iFrame % 64) * 17.0);
    vec3 acc = vec3(0.0);
    float w = 1.0;
    for (int i = 0; i < 40; i++) {
        if (i >= n)
            break;
        acc += min(passBilinear(B, p).rgb, vec3(16.0)) * w;
        w *= decay;
        p -= stp;
    }
    acc *= 3.0 / float(n);
    // beams: some directions brighter than others (integer frequencies, so there is no seam all around)
    vec2 d = dir * vec2(aspect, 1.0);
    float a = atan(d.y, d.x + 1e-6) + iTime * LIB_TAU / 16.0 * ray_spin;
    float k = float(ray_count);
    float b = 0.5 + 0.28 * sin(a * k + 1.3) + 0.14 * sin(a * (k * 2.0 + 1.0) - iTime * 0.21) + 0.08 * sin(a * (k * 3.0 + 2.0) + 2.1);
    float far = smoothstep(0.02, 0.35, length(d));
    acc *= mix(1.0, 0.15 + 2.2 * b * b, far);
    fragColor = vec4(acc, 1.0);
}
