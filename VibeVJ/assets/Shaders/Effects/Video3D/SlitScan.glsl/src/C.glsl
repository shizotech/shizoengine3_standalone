//@settings dtype=uint8 format=rgba rendersize=(3840,2164)
// --- SlitScan, pass C: the ring of the last frames, an atlas of tiles plus rows of state (lib/common.glsl) ---
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 px = ivec2(floor(fragCoord));
    int g = gridSize();
    int n = g * g;
    ivec4 st = readState(feedback);
    int head = st.x;
    int counter = st.y;
    int filled = st.z;
    bool reset = iFrame < 2 || st.w != cache_frames + 1;
    if (reset) {
        head = n - 1;
        counter = record_every;
        filled = 0;
    }
    bool record = !freeze && counter + 1 >= record_every;
    if (record) {
        head = (head + 1) % n;
        counter = 0;
        filled = min(filled + 1, n);
    } else {
        counter = min(counter + 1, 255);
    }

    if (px.y >= STATE_ROW) {
        fragColor = vec4(float(head), float(counter), float(filled), float(cache_frames + 1)) / 255.0;
        return;
    }

    ivec2 tileSize = ATLAS / g;
    ivec2 tile = px / tileSize;
    int index = tile.y * g + tile.x;
    if (tile.x >= g || tile.y >= g) {
        fragColor = vec4(0.0);
        return;
    }
    if (!record || index != head) {
        fragColor = reset ? vec4(0.0) : texelFetch(feedback, px, 0);
        return;
    }
    // the newest frame: the input scaled into this tile, 4 reads a texel against flicker
    vec2 uv = (vec2(px - tile * tileSize) + 0.5) / vec2(tileSize);
    vec2 d = 0.25 / vec2(tileSize);
    fragColor = 0.25 * (texture(input, uv + vec2(-d.x, -d.y)) + texture(input, uv + vec2(d.x, -d.y))
                      + texture(input, uv + vec2(-d.x, d.y)) + texture(input, uv + vec2(d.x, d.y)));
}
