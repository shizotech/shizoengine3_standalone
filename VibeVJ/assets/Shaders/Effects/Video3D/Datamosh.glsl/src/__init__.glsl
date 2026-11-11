//@settings dtype=float32 format=rgba
// --- Datamosh: the video melts and smears along its own motion, like a broken video file (datamoshing) ---
// lib/common.glsl says how it works. This pass moves its own last picture along the block vectors of V and adds the
// change of the input (a P-frame applied to the wrong picture), heals it back by Decay, and mixes by Mosh.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D P;
uniform sampler2D W;
uniform sampler2D S;
uniform sampler2D feedback;

//@enum options=(Beats, Hold only, Always) value=0
uniform int mosh_trigger;           // Beats: moshes Mosh beats of every Mosh cycle beats; Hold only: while Mosh hold is on
//@button
uniform bool mosh_hold;             // moshes while it is on, in every trigger mode (map it to a MIDI pad)
//@slider min=0.0 max=1.0 value=1.0
uniform float mosh;                 // how much it moshes while it does (a fader for MIDI)
//@int min=1 max=64 value=6
uniform int mosh_beats;             // Beats: how many beats it moshes
//@int min=1 max=64 value=8
uniform int mosh_cycle;             // Beats: every how many beats it starts again (the beats left over are clean)
//@slider min=0.0 max=0.3 value=0.0
uniform float decay;                // how fast the moshed picture heals back to the live one (a share a frame)
//@slider min=0.0 max=1.5 value=0.25
uniform float residual;             // how much of the change of the input comes through (0: only the old picture moves)
//@slider min=0.0 max=1.0 value=0.0
uniform float color_bleed;          // the colours run further than the brightness
//@enum options=(Moshed, Motion vectors) value=0
uniform int output_mode;            // Motion vectors: the motion as colours (direction = hue), to set it up

vec3 hueColor(float h) {
    return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    ivec2 ip = ivec2(fragCoord);
    vec4 pk = texelFetch(P, ip, 0);
    vec3 now = unpackColor(pk.x);
    float inAlpha = texture(input, uv).a;

    // the motion of the block here, in pixels of the picture a frame; plus the slow melt
    vec2 vsz = vec2(textureSize(W, 0));
    vec2 v = texelFetch(W, clamp(ivec2(uv * vsz), ivec2(0), ivec2(vsz) - 1), 0).xy * 4.0 * strength;
    // the beat: random blocks jump the wrong way for a moment
    vec4 hit = musicHit(S);
    if (glitch_blocks > 0.0 && hit.y < 0.3) {
        vec2 block = floor(fragCoord / blockPx(res.y));
        float r = musicHash01(int(block.x) * 131 + int(block.y), int(hit.z) * 7 + 3);
        if (r < glitch_blocks * 0.3) {
            float a = MUSIC_TAU * musicHash01(int(block.y) * 17 + 5, int(block.x) + int(hit.z));
            v += vec2(cos(a), sin(a)) * blockPx(res.y) * 0.5;
        }
    }
    if (melt > 0.0) {
        float t = iTime * 0.2;
        vec2 q = uv * vec2(res.x / res.y, 1.0) * 3.0;
        v += melt * res.y / 1080.0 * 2.5 * vec2(sin(q.y * 1.7 + t * 2.3) + sin(q.x * 0.9 - t * 1.1),
                                                 cos(q.x * 1.3 - t * 1.9) + cos(q.y * 2.1 + t * 0.7));
    }

    if (output_mode == 1) {
        float m = clamp(length(v) / (res.y / 1080.0 * 12.0), 0.0, 1.0);
        fragColor = vec4(hueColor(atan(v.y, v.x) / MUSIC_TAU + 0.5) * m + now * 0.25, 1.0);
        return;
    }

    // how much it moshes now
    float m = 0.0;
    if (mosh_trigger == 2)
        m = 1.0;
    else if (mosh_trigger == 0) {
        float ph = mod(iTime, float(max(mosh_cycle, 1)));
        m = ph < float(mosh_beats) ? 1.0 : 0.0;
    }
    if (mosh_hold)
        m = 1.0;
    m *= mosh;

    vec4 last = stateOr(texelFetch(feedback, ip, 0), vec4(now, 1.0));
    if (iFrame < 3 || m <= 0.0) {
        fragColor = vec4(now, inAlpha);
        return;
    }
    // a P-frame on the wrong picture: the last moshed picture moved along the motion, plus what changed in the input
    vec2 src = fragCoord - v;
    vec3 moved = passBilinear(feedback, src / res).rgb;
    vec3 before = unpackColor(texelFetch(P, clamp(ivec2(src), ivec2(0), ivec2(res) - 1), 0).y);
    vec3 change = now - before;
    if (color_bleed > 0.0) {
        // the change of the brightness comes through, the change of the colour less
        float lc = lumaOf(change);
        change = mix(change, vec3(lc), color_bleed);
    }
    vec3 moshed = moved + residual * change;
    moshed = mix(moshed, now, decay);
    moshed = clamp(moshed, 0.0, 1.0);
    fragColor = vec4(mix(now, moshed, m), inAlpha);
}
