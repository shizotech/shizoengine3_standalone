//@settings dtype=float32 format=rgba rendersize=(4,1)
// --- pass S: the state, 4 pixels (lib/common.glsl names them): the levels of the music, the beat and glitch
// envelopes, whether the sound counts, and a damped spring the music pushes (so the object moves like a thing with
// mass). It remembers the iTime of the last frame, so a stopped timeline does not fire a beat in every frame. ---
#include lib/common.glsl

uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int px = int(fragCoord.x);
    vec4 lv0 = stateOr(texelFetch(feedback, ivec2(ST_LEVELS, 0), 0), vec4(0.0));
    vec4 bt0 = stateOr(texelFetch(feedback, ivec2(ST_BEAT, 0), 0), vec4(0.0, 0.0, 0.0, iTime));
    vec4 sd0 = stateOr(texelFetch(feedback, ivec2(ST_SOUND, 0), 0), vec4(0.0, 0.0, 100.0, 0.0));
    vec4 sp0 = stateOr(texelFetch(feedback, ivec2(ST_SPRING, 0), 0), vec4(0.0));
    if (iFrame < 2) {
        lv0 = vec4(0.0);
        bt0 = vec4(0.0, 0.0, 0.0, iTime);
        sd0 = vec4(0.0, 0.0, 100.0, 0.0);
        sp0 = vec4(0.0);
    }
    float dt = clamp(iTimeDelta, 0.0, 0.1);

    // the sound: three bands and the loudness
    vec4 snd = vec4(bandMean(30.0, 150.0), bandMean(250.0, 2000.0), bandMean(4000.0, 14000.0), bandMean(30.0, 14000.0));
    snd = clamp(snd * music_gain * vec4(1.3, 1.8, 2.6, 1.6), 0.0, 1.5);
    bool heard = AUDIO_ON == 1 || snd.w > 0.002;
    // the sound counts while it was heard in the last 2 seconds (a quiet bar does not switch to the beat)
    float since = heard ? 0.0 : sd0.z + dt;
    bool soundOn = (music == 1) || (music == 0 && since < 2.0);
    vec4 target = music == 3 ? vec4(0.0) : (soundOn ? snd : beatLevels(iTime));
    // fast up, slower down: a level follows a kick at once and falls in about 0.15 s
    vec4 k = mix(vec4(1.0 - exp(-dt / 0.15)), vec4(1.0 - exp(-dt / 0.03)), step(lv0, target));
    vec4 lv = mix(lv0, target, k);
    if (soundOn && !heard)
        lv = lv0 * exp(-dt / 0.3);

    // a kick: the bass jumps over its slow mean
    float slow = mix(sd0.x, lv.x, 1.0 - exp(-dt / 0.8));
    float kickEnv = sd0.y * exp(-dt / 0.12);
    if (lv.x - slow > 0.12 && lv.x > sd0.x + 0.02 && sd0.y < 0.5)
        kickEnv = 1.0;
    if (!soundOn)
        kickEnv = lv.x;

    // the beat: a new whole beat of iTime (only forwards: a stopped timeline fires nothing)
    bool newBeat = floor(iTime) != floor(bt0.w) && iTime > bt0.w && iTime - bt0.w < 2.0;
    float beatEnv = newBeat ? 1.0 : bt0.x * exp(-dt / 0.25);
    float g = bt0.y * exp(-dt / max(glitch_length, 0.05) * 3.0);
    float seed = bt0.z;
    int beatNo = int(floor(iTime));
    if (newBeat && glitch_on_beat > 0.0 && beatNo % max(glitch_every, 1) == 0) {
        g = max(g, glitch_on_beat);
        seed = fract(seed + 0.618034 + 0.1 * fract(iTime * 0.37));
    }
    if (soundOn && kickEnv >= 1.0 && sd0.y < 0.5 && glitch_on_sound > 0.0) {
        g = max(g, glitch_on_sound);
        seed = fract(seed + 0.618034);
    }

    // the spring: pushed by the bass and the kicks, it overshoots a little and settles
    float push = react * (0.7 * lv.x + 0.3 * kickEnv);
    float stiff = SPRING_STIFF, damp = SPRING_DAMP;
    float acc = stiff * (push - sp0.x) - damp * sp0.y;
    float vel = sp0.y + acc * dt;
    float pos = sp0.x + vel * dt;

    if (px == ST_LEVELS)
        fragColor = lv;
    else if (px == ST_BEAT)
        fragColor = vec4(beatEnv, g, seed, iTime);
    else if (px == ST_SOUND)
        fragColor = vec4(slow, kickEnv, min(since, 100.0), soundOn ? 1.0 : 0.0);
    else
        fragColor = vec4(pos, vel, 0.0, 0.0);
}
