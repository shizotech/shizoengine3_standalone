// ---- Datamosh: what the passes share ----
// A video codec saves most frames as "move these blocks of the last frame by these vectors, then add this little
// difference". Datamoshing drops the real pictures in between, so the vectors and differences of new frames are put
// on an old picture: it smears, melts and bleeds along the motion. This asset does the same with the live input:
// P keeps the input of this frame and of the last one (packed, 8 bits a channel, into a float32 texel); G is their
// brightness at a quarter of the size; V finds for every block where it came from in the last frame (block matching
// with a three-step search, like an encoder) and keeps the vectors (Hold vectors: the last ones go on pushing, the
// "bloom" of a datamosh), and W smooths them (the median of the 3 x 3 blocks around). __init__ moves its own last picture along the vectors and adds what changed in the input
// (Residual): while it moshes, the picture melts; Decay heals it back to the live input. S keeps the music.
#include music.glsl

//@enum options=(8 px, 16 px, 32 px, 64 px) value=1
uniform int block_size;             // the blocks that move together (at 1080p)
//@int min=1 max=3 value=2
uniform int quality;                // the search: 1 up to 12, 2 up to 28, 3 up to 60 pixels a frame (at 1080p)
//@slider min=0.0 max=4.0 value=1.0
uniform float strength;             // multiplies the motion
//@slider min=0.0 max=1.0 value=0.25
uniform float melt;                 // a slow flow added to the motion, so a still picture melts too
//@button
uniform bool hold_vectors;          // the vectors stop changing and keep pushing the same way (map it to a MIDI pad)
//@slider min=0.0 max=1.0 value=0.35
uniform float glitch_blocks;        // on the beat (every Beat every-th) random blocks jump the wrong way

// The block size in pixels of this picture
float blockPx(float height) {
    float b = block_size == 0 ? 8.0 : (block_size == 1 ? 16.0 : (block_size == 2 ? 32.0 : 64.0));
    return max(4.0, floor(b * height / 1080.0 + 0.5));
}

float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// A colour as one float (8 bits a channel, exact in float32) and back
float packColor(vec3 c) {
    ivec3 i = ivec3(clamp(c, 0.0, 1.0) * 255.0 + 0.5);
    return float(i.r * 65536 + i.g * 256 + i.b);
}
vec3 unpackColor(float v) {
    int i = int(v + 0.5);
    return vec3(float((i >> 16) & 255), float((i >> 8) & 255), float(i & 255)) / 255.0;
}

// A texture of a pass at uv, bilinear (the textures of passes are nearest)
vec4 passBilinear(sampler2D s, vec2 uv) {
    ivec2 sz = textureSize(s, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    ivec2 a = ivec2(i);
    ivec2 mx = sz - 1;
    vec4 c00 = texelFetch(s, clamp(a, ivec2(0), mx), 0);
    vec4 c10 = texelFetch(s, clamp(a + ivec2(1, 0), ivec2(0), mx), 0);
    vec4 c01 = texelFetch(s, clamp(a + ivec2(0, 1), ivec2(0), mx), 0);
    vec4 c11 = texelFetch(s, clamp(a + ivec2(1, 1), ivec2(0), mx), 0);
    return mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
}
