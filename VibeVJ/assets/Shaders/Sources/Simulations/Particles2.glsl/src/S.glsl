//@settings dtype=float32 format=rgba rendersize=(1024,2048)
// --- Particles 2, pass S: the particles (lib/common.glsl says how they are stored) ---
#include lib/common.glsl

uniform sampler2D feedback;
uniform sampler2D T;
uniform sampler2D main_image;       // only its size: the aspect of the picture

struct Spawn {
    vec3 pos;
    vec3 vel;
    float life;
};

// A direction on the unit sphere from two random numbers
vec3 randomUnit(vec2 u) {
    float z = u.x * 2.0 - 1.0;
    float a = u.y * TAU;
    float r = sqrt(max(1.0 - z * z, 0.0));
    return vec3(r * cos(a), r * sin(a), z);
}

// A new particle: where it is born and how it starts. Both halves of S call this with the same numbers.
Spawn spawnParticle(int id, int salt, bool burst, float aspect) {
    vec4 r = rand4(id, salt);
    vec4 q = rand4(id, salt + 7919);
    Spawn s;
    s.life = lifetime * (0.5 + r.w);
    vec3 dir = randomUnit(r.xy);
    vec3 other = randomUnit(q.yz);
    float speed = start_speed * (1.0 - spread * q.x);
    vec3 c = emitter_position;
    if (emitter == 0) {
        // Volume: a box, Emitter size 0.35 is about the picture
        s.pos = c + (vec3(r.z, q.w, fract(r.z + q.y * 7.31)) * 2.0 - 1.0) * vec3(aspect, 1.0, 1.0) * emitter_size * 2.9;
        s.vel = dir * speed;
    } else if (emitter == 1) {
        // Sphere: on its surface, out
        s.pos = c + dir * emitter_size;
        s.vel = normalize(mix(dir, other, spread) + 1e-4) * speed;
    } else if (emitter == 2) {
        // Ring: lying flat (around the upright axis), out
        float a = r.x * TAU;
        vec3 rd = vec3(cos(a), 0.0, sin(a));
        s.pos = c + rd * emitter_size + other * 0.01;
        s.vel = normalize(mix(rd, dir, spread) + 1e-4) * speed;
    } else if (emitter == 3) {
        // Fountain: a small disc that shoots up
        float a = r.x * TAU;
        float rr = sqrt(r.y) * emitter_size * 0.3;
        s.pos = c + vec3(cos(a) * rr, 0.0, sin(a) * rr);
        s.vel = normalize(vec3(0.0, 1.0, 0.0) + other * spread * 0.6) * speed * 2.0;
    } else if (emitter == 4) {
        // Field picture: the brightest of a few random points of the picture, flat on the picture plane
        vec2 best = vec2(0.5);
        float bestL = -1.0;
        for (int i = 0; i < 6; i++) {
            vec2 uv = rand4(id, salt + 31 * i + 101).xy;
            float l = lumaOf(textureLod(field, uv, 0.0).rgb);
            if (l > bestL) {
                bestL = l;
                best = uv;
            }
        }
        s.pos = vec3((best * 2.0 - 1.0) * vec2(aspect, 1.0), (q.x - 0.5) * emitter_size * 0.2);
        s.vel = dir * speed * 0.3;
        if (bestL < 0.04)
            s.life = 0.0;           // nothing bright found: born again in the next frame
    } else {
        // Galaxy: a flat disc with three spiral arms, turning
        float arm = floor(r.x * 3.0);
        float rr = pow(r.y, 0.7) * emitter_size * 3.0;
        float a = arm / 3.0 * TAU + rr * 2.5 + (q.y - 0.5) * (0.3 + 0.9 * spread);
        s.pos = c + vec3(cos(a) * rr, (q.z - 0.5) * 0.08 * (1.0 - rr / (emitter_size * 3.0 + 1e-3)), sin(a) * rr);
        s.vel = vec3(-sin(a), 0.0, cos(a)) * speed * (0.5 + rr) + other * speed * 0.2 * spread;
    }
    if (burst) {
        s.pos = c + dir * emitter_size * 0.3;
        s.vel = normalize(mix(dir, other, 0.3 * spread) + 1e-4) * burst_speed * (0.5 + 0.5 * q.x);
    }
    return s;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 c = ivec2(floor(fragCoord));
    bool velHalf = c.y >= SIM_H;
    ivec2 ca = ivec2(c.x, velHalf ? c.y - SIM_H : c.y);
    int id = ca.y * SIM_W + ca.x;
    vec4 A = texelFetch(feedback, ca, 0);                       // position, age
    vec4 B = texelFetch(feedback, ca + ivec2(0, SIM_H), 0);     // velocity, lifetime
    bool init = reset || iFrame < 2 || textureSize(feedback, 0) != ivec2(SIM_W, 2 * SIM_H)
        || any(isnan(A)) || any(isnan(B)) || any(isinf(A)) || any(isinf(B));
    // a particle past the count keeps what it had and costs one read
    if (id >= particles && !init) {
        fragColor = velHalf ? B : A;
        return;
    }

    vec2 pic = vec2(textureSize(main_image, 0));
    float aspect = pic.y > 1.0 ? pic.x / pic.y : 16.0 / 9.0;
    float dt = clamp(iTimeDelta, 0.0, 0.1);
    vec4 beat = texelFetch(T, ivec2(0), 0);
    vec3 box = vec3(aspect, 1.0, 1.0) * bounds;
    bool outside = edge_mode == 1 && any(greaterThan(abs(A.xyz), box));
    bool burst = beat.a > 0.5 && rand4(id, 1000003 + int(floor(iTime))).x < beat_burst;
    if (init || A.w >= B.w || outside || burst) {
        Spawn s = spawnParticle(id, iFrame, burst && !init, aspect);
        // the first particles start with random ages, so they do not all die at the same time
        float age = init ? rand4(id, 77).y * s.life : 0.0;
        fragColor = velHalf ? vec4(s.vel, s.life) : vec4(s.pos, age);
        return;
    }

    if (!velHalf) {
        vec3 p = A.xyz + B.xyz * dt;
        if (edge_mode == 2)
            p = mod(p + box, 2.0 * box) - box;
        fragColor = vec4(p, A.w + dt);
    } else {
        vec3 v = B.xyz + particleForce(A.xyz, B.xyz, aspect) * dt;
        v *= exp(-drag * dt);
        // the beat kick: a push away from the emitter position in the frame the beat starts
        vec3 d = A.xyz - emitter_position;
        v += beat_kick * beat.a * d / max(length(d), 0.05);
        fragColor = vec4(v, B.w);
    }
}
