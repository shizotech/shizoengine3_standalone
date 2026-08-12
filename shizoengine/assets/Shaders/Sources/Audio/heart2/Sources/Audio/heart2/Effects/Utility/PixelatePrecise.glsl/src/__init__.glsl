// ==== Custom Uniform Controls ====

//@int min=1 max=512 value=64
uniform int target_width;

//@int min=1 max=512 value=36
uniform int target_height;

//@int min=1 max=8 value=2
uniform int sample_step;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Compute pixel size based on the target virtual resolution
    float px = iResolution.x / float(max(1, target_width));
    float py = iResolution.y / float(max(1, target_height));
    vec2 blockSize = vec2(px, py);

    // Top-left corner of the current pixel block
    vec2 blockOrigin = floor(fragCoord / blockSize) * blockSize;

    // Multisampling
    int steps = max(1, sample_step);
    float totalSamples = float(steps * steps);
    vec3 color = vec3(0.0);

    for (int x = 0; x < 8; ++x) {
        if (x >= steps) break;
        for (int y = 0; y < 8; ++y) {
            if (y >= steps) break;

            vec2 offset = (vec2(x, y) + 0.5) / float(steps); // center of subcell
            vec2 samplePos = blockOrigin + offset * blockSize;
            vec2 uv = samplePos / iResolution.xy;

            color += texture(iChannel0, uv).rgb;
        }
    }

    color /= totalSamples;
    fragColor = vec4(color, 1.0);
}
