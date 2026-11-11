//@settings dtype=float32 format=rgba renderscale=0.5
// --- EdgeSweep, pass R: the comets of Trace. A comet is carried along the tangent of the nearest outline each
// frame and put back onto the line (the seed of the place it came from), so it follows the outline around corners.
// r: comets running with the tangent, g: against it ---
#define PASS_SCALE 0.5
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D J10;
uniform sampler2D T;

//@slider min=0.0 max=16.0 value=3.0
uniform float trace_speed;    // pixels per frame
//@slider min=0.0 max=1.0 value=0.7
uniform float trace_tail;     // the length of the tail
//@slider min=0.0 max=1.0 value=0.45
uniform float trace_spawn;    // how many comets start at a pulse
//@slider min=0.0 max=1.0 value=0.25
uniform float trace_flow;     // comets that start all the time, also while the timeline stands
//@enum options=(Forward, Backward, Both) value=2
uniform int trace_direction;

vec4 seed_at(vec2 q) {
    return texelFetch(J10, clamp(ivec2(floor(q)), ivec2(0), textureSize(J10, 0) - 1), 0);
}

// From the point q on the line, half a step along the tangent (dir 1 or -1), put back onto the line
vec2 walk(vec2 q, float dir, float v) {
    vec4 s = seed_at(q);
    vec2 t = vec2(-sin(s.z), cos(s.z));
    vec4 s2 = seed_at(q + t * v * 0.5 * dir);
    return s2.w > 0.5 ? s2.xy : q;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(0.0);
    if (sweep_mode != 3) return;
    vec4 s = texelFetch(J10, ivec2(fragCoord), 0);
    if (s.w < 0.5 || distance(s.xy, fragCoord) > 2.0) return;
    float v = trace_speed * PASS_SCALE;
    float decay = mix(0.86, 0.993, trace_tail);
    // where the comet of this place was a frame ago: two half steps back, so it follows a curve
    vec2 qa = walk(walk(s.xy, -1.0, v), -1.0, v);
    vec2 qb = walk(walk(s.xy, 1.0, v), 1.0, v);
    float a = mp_bilinear(feedback, qa).r * decay;
    float b = mp_bilinear(feedback, qb).g * decay;
    if (iFrame < 2) {
        a = 0.0;
        b = 0.0;
    }

    vec3 pl = mp_pulse(T);
    ivec2 cell = ivec2(floor(s.xy / 3.0));
    bool start = pl.z > 0.5 && mp_rand3(ivec3(cell, int(pl.y))) < trace_spawn * trace_spawn * 0.03;
    start = start || mp_rand3(ivec3(cell, iFrame + 100003)) < trace_flow * trace_flow * 0.0015;
    if (start) {
        int dir = trace_direction;
        if (dir == 2) dir = mp_rand2(cell + ivec2(17, 3)) < 0.5 ? 0 : 1;
        if (dir == 0) a = 1.0;
        else b = 1.0;
    }
    fragColor = vec4(a, b, 0.0, 1.0);
}
