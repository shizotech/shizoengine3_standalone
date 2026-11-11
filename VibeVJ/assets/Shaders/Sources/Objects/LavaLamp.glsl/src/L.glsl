//@settings dtype=float32 format=rgba rendersize=(32,2)
// --- pass L: the drops of wax, one column each. Row 0: position (x, y), the speed of its wobble, temperature (0 cold
// .. 1 hot); row 1: velocity. The lamp under the picture heats a drop at the bottom, warm wax is lighter than the
// liquid and rises, it cools at the top and sinks again; the drops drift sideways, stick together a little where they
// touch (they melt into one and tear apart again) and share their heat. The music adds heat (the bass through the
// spring of pass S) and kicks the warm drops up. Every third drop swims further back and meets only its own kind. ---
#include lib/common.glsl

uniform sampler2D S;
uniform sampler2D feedback;

vec4 initPos(int i) {
    vec3 h = hash33(vec3(float(i), 1.0, 2.0));
    return vec4((h.x * 2.0 - 1.0) * SIM_ASPECT * 0.92, mix(-0.95, 0.95, h.y), 0.5 + h.y, h.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int i = int(fragCoord.x), row = int(fragCoord.y);
    vec4 ps = stateOr(texelFetch(feedback, ivec2(i, 0), 0), initPos(i));
    vec4 vs = stateOr(texelFetch(feedback, ivec2(i, 1), 0), vec4(0.0));
    if (iFrame < 2 || abs(ps.y) > 4.0 || abs(ps.x) > 4.0) {
        ps = initPos(i);
        vs = vec4(0.0);
    }
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    vec4 sd = texelFetch(S, ivec2(ST_SOUND, 0), 0);
    float dt = clamp(iTimeDelta, 0.0, 0.05) * flow;
    float r = blobRadius(i);
    vec2 p = ps.xy;
    vec2 v = vs.xy;
    float T = ps.w;
    bool back = isBack(i);

    // heat at the bottom (more with the music), cooling everywhere, more at the top; small drops change faster
    float hot = smoothstep(-0.45, -0.95, p.y);
    float coolTop = smoothstep(0.1, 1.0, p.y);
    float warm = heat * (1.0 + 1.5 * max(sp.x, 0.0));
    float rate = clamp(0.16 / r, 0.6, 1.8);
    T += dt * rate * (0.9 * warm * hot * (1.3 - T) - 0.25 * (0.06 + coolTop) * T);

    // warm wax rises, cool wax sinks; the liquid holds it back
    vec2 acc = vec2(0.0);
    acc.y = buoyancy * (T - 0.48) * 0.6;
    // a slow sideways drift
    float t = iTime * 0.04 + float(i) * 7.3;
    acc.x += gradientNoise(vec2(t, float(i) * 3.1)) * 0.22;
    // the sides of the picture: a soft wall just outside
    float wx = SIM_ASPECT - r * 0.4;
    if (abs(p.x) > wx)
        acc.x -= sign(p.x) * (abs(p.x) - wx) * 12.0;
    // the other drops of its layer: pushed apart when they overlap a lot, dragged along where they touch (so they
    // melt into one for a while and tear apart when one is warmer), the heat flows a little from the warmer to the
    // cooler one, and all keep a little distance, so they spread over the picture instead of clumping
    for (int j = 0; j < MAXBLOBS; j++) {
        if (j >= blobs || j == i || isBack(j) != back)
            continue;
        vec4 q = texelFetch(feedback, ivec2(j, 0), 0);
        vec2 dd = p - q.xy;
        float dl = length(dd);
        float rr = r + blobRadius(j);
        if (dl < 1e-4 || dl > rr * 2.4)
            continue;
        vec2 dir = dd / dl;
        if (dl < rr * 0.6)
            acc += dir * (rr * 0.6 - dl) * 9.0;
        acc += dir * 0.07 * (1.0 - dl / (rr * 2.4));
        float touch = smoothstep(rr * 1.05, rr * 0.7, dl);
        acc += (texelFetch(feedback, ivec2(j, 1), 0).xy - v) * 1.2 * merge * touch;
        T += dt * 0.06 * (q.w - T) * touch;
    }
    T = clamp(T, 0.0, 1.25);
    // a kick lifts the warm drops
    acc.y += sd.y * react * 0.5 * smoothstep(0.4, 1.0, T);
    v += acc * dt;
    v *= exp(-dt * 1.3);
    p += v * dt;
    // the bottom and the top: a drop may hang over the edge a little
    float lo = -1.02 - r * 0.2, hi = 1.02 + r * 0.2;
    if (p.y < lo) {
        p.y = lo;
        v.y = max(v.y, 0.0);
    }
    if (p.y > hi) {
        p.y = hi;
        v.y = min(v.y, 0.0);
    }
    fragColor = row == 0 ? vec4(p, ps.z, T) : vec4(v, 0.0, 0.0);
}
