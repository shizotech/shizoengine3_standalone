// MFX3 EyeWarp - Distort input into an eye shape
// Shadertoy format (effect: needs input)
// Warps the input (iChannel0) into an eye: the input's center remains
// visible inside the iris; rays stretch out to the screen edges outside the eye.
// Controls: size, zoom, frame-width, inside-blur and outside-smoothness.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Eye size (fraction of the frame)
//@slider min=0.1 max=0.9 value=0.5
uniform float eye_size;

// Zoom of the input inside the eye
//@slider min=0.2 max=3.0 value=1.0
uniform float zoom;

// Width of the eye's frame / ring (fraction)
//@slider min=0.02 max=0.4 value=0.08
uniform float frame_width;

// Blur applied inside the iris
//@slider min=0.0 max=1.0 value=0.3
uniform float inside_blur;

// Number of blur taps
//@int min=2 max=8 value=4
uniform int blur_taps;

// Smoothness of the outside (ray) transition
//@slider min=0.0 max=1.0 value=0.4
uniform float outside_smoothness;

// Number of rays stretching to the edges
//@int min=0 max=32 value=12
uniform int ray_count;

// Background fill for out-of-bounds
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    float r = length(p);
    float a = atan(p.y, p.x);

    // Radii:
    //  - irisR: radius of the central iris, where the input center is visible
    //  - eyeR:  outer radius of the eye
    //  - frameR_in: inner radius of the sclera/frame rim
    float eyeR = eye_size;
    float irisR = eye_size * 0.5;
    float frameR_in = max(eye_size - frame_width, irisR + 0.01);

    // ---- INSIDE: zoomed input so the center stays recognizable ----
    vec2 ip = p / max(zoom, 0.001);
    vec2 in_uv = ip * 0.5 + 0.5;

    // Region masks (monotonic smoothstep edges, all edge0 < edge1)
    float irisMask  = 1.0 - smoothstep(irisR - 0.02, irisR + 0.02, r);
    float frameMask = smoothstep(irisR + 0.02, irisR + 0.04, r) * (1.0 - smoothstep(frameR_in - 0.02, frameR_in + 0.02, r));
    float outMask   = smoothstep(eyeR, eyeR + max(outside_smoothness, 0.02), r);

    // Sample the input inside (with optional inside-blur)
    vec3 bg = background;
    vec3 inCol = texture(iChannel0, clamp(in_uv, vec2(0.0), vec2(1.0))).rgb;
    inCol = mix(bg, inCol, step(0.0, in_uv.x) * step(in_uv.x, 1.0) * step(0.0, in_uv.y) * step(in_uv.y, 1.0));
    if (inside_blur > 0.001) {
        float radius = inside_blur * 4.0;
        vec3 sum = vec3(0.0);
        float cnt = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 off = vec2(x, y) * radius / iResolution.xy;
                if (abs(float(x)) <= blur_taps && abs(float(y)) <= blur_taps) {
                    sum += texture(iChannel0, clamp(in_uv + off, vec2(0.0), vec2(1.0))).rgb;
                    cnt += 1.0;
                }
            }
        }
        vec3 blurred = (cnt > 0.0) ? sum / cnt : inCol;
        inCol = mix(inCol, blurred, irisMask);
    }

    // ---- OUTSIDE: rays stretch the input toward the screen edges ----
    float rayFreq = max(ray_count, 1);
    float rayMod = 0.5 + 0.5 * cos(a * float(rayFreq));
    vec2 stretched = p * (1.0 + 0.3 * rayMod);
    vec2 out_uv = stretched / max(zoom, 0.001) * 0.5 + 0.5;
    vec3 outCol = texture(iChannel0, clamp(out_uv, vec2(0.0), vec2(1.0))).rgb;
    // darken/fade outside toward the edges, modulated by rays
    float fadeStart = eye_size;
    float fadeEnd = min(eye_size + 0.2, 0.98);
    outCol = mix(outCol * (0.3 + 0.7 * rayMod), bg, smoothstep(fadeStart, fadeEnd, r));

    // ---- Compose regions ----
    // inside (iris) + frame ring + outside (rays)
    vec3 frameCol = mix(bg, outCol, 0.4);
    vec3 col = inCol * irisMask + frameCol * frameMask + outCol * outMask;

    col = max(bg, col);
    fragColor = vec4(col, 1.0);
}
