// ==== Custom Uniform Controls ====

//@int min=1 max=512 value=128
uniform int pixel_width;

//@int min=1 max=512 value=128
uniform int pixel_height;

//@int min=1 max=16 value=4
uniform int sample_step;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float px = float(max(1, pixel_width));
    float py = float(max(1, pixel_height));
    int steps = max(1, sample_step);
    
    vec2 blockSize = vec2(px, py);
    vec2 blockOrigin = floor(fragCoord / blockSize) * blockSize;

    vec3 color = vec3(0.0);
    float totalSamples = float(steps * steps);

    for (int x = 0; x < 8; ++x) {
        if (x >= steps) break;
        for (int y = 0; y < 8; ++y) {
            if (y >= steps) break;

            // Offset inside the block: center of subcell
            vec2 offset = (vec2(x, y) + 0.5) / float(steps);
            vec2 samplePos = blockOrigin + offset * blockSize;
            vec2 uv = samplePos / iResolution.xy;

            color += texture(iChannel0, uv).rgb;
        }
    }

    color /= totalSamples;
    fragColor = vec4(color, 1.0);
}
