// Discotunnel Audio Pass - extracts and accumulates FFT data
// Created by SHAU - 2018
// iChannel1 provides the AUDIO/FFT input from the engine

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    vec2 uv = fragCoord.xy / iResolution.xy;

    vec4 currentSound = texture(iChannel0, uv / iResolution.xy);

    float level = currentSound.x;
    float bass = currentSound.y;
    float mid = currentSound.z;
    float treble = currentSound.w;

    for (int x = 0; x < 512; x++) {
        vec4 newSound = texelFetch(iChannel1, ivec2(x, 0), 0);
        level += newSound.x;
        if (x < 140) bass += newSound.x;
        if (x > 139 && x < 300) mid += newSound.x;
        if (x > 299) treble += newSound.x;
    }

    level /= 60.0;
    bass /= 60.0;
    mid /= 20.0;
    treble /= 36.0;

    fragColor = vec4(level, bass, mid, treble);
}
