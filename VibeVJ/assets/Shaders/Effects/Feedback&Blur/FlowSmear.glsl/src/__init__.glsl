// --- FlowSmear: the picture carried along by its own motion, a datamosh look ---
// The passes G, G2, F2 and F estimate how the input moves (optical flow, lib/common.glsl). This pass keeps its last
// frame and moves it by that motion every frame instead of showing the new frame, as a video whose key frames were
// taken out does: the old picture smears and melts along whatever moves in the new one. Refresh lets the input
// back in, Still refresh where nothing moves, a key frame every few beats shows the input clean again.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D F;
uniform sampler2D feedback;

//@slider min=0.0 max=4.0 value=1.5
uniform float smear;                // how far the picture is carried, times the motion
//@slider min=0.0 max=0.5 value=0.02
uniform float refresh;              // share of the input let in every frame (0 = never)
//@slider min=0.0 max=1.0 value=0.15
uniform float still_refresh;        // where nothing moves, the input comes back this fast
//@slider min=0.0 max=0.5 value=0.03
uniform float motion_threshold;     // smaller moves count as still
//@enum options=(Off, 8 px, 16 px, 32 px) value=2
uniform int block_size;             // moves the picture in blocks, like a broken video stream
//@slider min=0.0 max=16.0 value=4.0
uniform float keyframe_beats;       // a clean frame every this many beats (0 = never)
//@slider min=0.0 max=0.2 value=0.0
uniform float color_drift;          // the carried picture turns its colours a little every frame
//@button
uniform bool reset;                 // shows the input clean while it is on

vec3 hueTurn(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a);
    return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    bool keyframe = keyframe_beats > 0.0 && mod(iTime, keyframe_beats) < max(iTimeDelta, 1e-4);
    if (reset || iFrame < 3 || keyframe) {
        fragColor = src;
        return;
    }

    // the motion here; with blocks, the motion of the middle of the block for the whole block
    vec2 at = uv;
    if (block_size > 0) {
        float b = block_size == 1 ? 8.0 : (block_size == 2 ? 16.0 : 32.0);
        b *= iResolution.y / 1080.0;
        at = (floor(fragCoord / b) + 0.5) * b / iResolution.xy;
    }
    vec3 f = sampleLinear(F, at).xyz;
    vec2 v = f.xy * smear;
    float speed = length(f.xy * iResolution.y);          // pixels per frame
    float moving = smoothstep(motion_threshold * 20.0, motion_threshold * 30.0 + 0.1, speed);

    vec4 carried = texture(feedback, uv - v);
    if (color_drift > 0.0)
        carried.rgb = clamp(hueTurn(carried.rgb, color_drift * moving), 0.0, 1.0);
    float r = clamp(refresh + still_refresh * (1.0 - moving), 0.0, 1.0);
    fragColor = vec4(mix(carried.rgb, src.rgb, r), src.a);
}
