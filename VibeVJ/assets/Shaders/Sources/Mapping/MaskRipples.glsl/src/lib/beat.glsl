// ---- Projection mapping building blocks (#586): the beat pulse and the trigger (pass T) ----
//@int min=0 max=32 value=1
uniform int pulse_every;    // a pulse every this many beats of the timeline; 0: only the trigger
//@slider min=0.0 max=1.0 value=0.5
uniform float pulse_decay;  // how long a pulse glows: 0 short, 1 long
//@button
uniform bool trigger;       // a pulse when it goes on: map it to a MIDI note or a pad

// The pass T: pixel 0 = (iTime, envelope, number of pulses, 1 in the frame of a pulse), pixel 1 = (trigger last frame)
vec4 mp_beat_pass(sampler2D last, ivec2 p) {
    vec4 a = texelFetch(last, ivec2(0, 0), 0);
    vec4 b = texelFetch(last, ivec2(1, 0), 0);
    bool first = iFrame < 2;
    float before = first ? iTime : a.r;
    float every = float(max(pulse_every, 1));
    bool beat = pulse_every > 0 && !first && iTime > before && floor(iTime / every + 1e-4) != floor(before / every + 1e-4);
    bool trig = trigger && b.r < 0.5 && !first;
    bool fire = beat || trig;
    float env = fire ? 1.0 : (first ? 0.0 : a.g * mix(0.8, 0.985, pulse_decay));
    float count = first ? 0.0 : a.b + (fire ? 1.0 : 0.0);
    if (p.x == 0) return vec4(iTime, env, count, fire ? 1.0 : 0.0);
    return vec4(trigger ? 1.0 : 0.0, 0.0, 0.0, 0.0);
}
