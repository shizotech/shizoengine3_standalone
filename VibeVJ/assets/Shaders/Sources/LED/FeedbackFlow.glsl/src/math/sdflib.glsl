// Shared math library for FeedbackFlow.
// This file lives in src/math/ and is only used via #include
// (helper files in subdirectories are never rendered on their own).
// It defines hashing, value-noise, a divergence-free flow field
// (curl of noise + a controllable vortex), and SDF primitives.

// --- hash / value-noise ---
float ff_hash(vec2 p)
{
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + vec3(34.0, 96.0, 124.0));
    return fract((p3.x + p3.y) * p3.z);
}

float ff_noise(vec2 p)
{
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    vec2 u = fp * fp * (3.0 - 2.0 * fp);
    float n00 = ff_hash(ip);
    float n10 = ff_hash(ip + vec2(1.0, 0.0));
    float n01 = ff_hash(ip + vec2(0.0, 1.0));
    float n11 = ff_hash(ip + vec2(1.0, 1.0));
    return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
}

// --- divergence-free flow field: curl of value-noise + vortex swirl ---
// Uses a guarded denominator for the finite-difference derivative and
// a guarded radius for the vortex term (no division by zero / no NaN).
vec2 ff_flow(vec2 p)
{
    const float E = 0.25;
    float up    = ff_noise(p + vec2(0.0, E));
    float down  = ff_noise(p - vec2(0.0, E));
    float left  = ff_noise(p - vec2(E, 0.0));
    float right = ff_noise(p + vec2(E, 0.0));

    float dPdy = (up - down) / (2.0 * E);
    float dPdx = (right - left) / (2.0 * E);
    vec2 curl = vec2(dPdy, -dPdx);

    // Controllable vortex around the origin (tangential velocity)
    float rlen = max(length(p), 1e-4);
    vec2 vortex = vec2(-p.y, p.x) * (swirl / rlen) * 0.2;

    return curl * 1.5 + vortex;
}

// --- SDF primitives (all in the same coordinate space as the caller) ---
float ff_sd_circle(vec2 q, float r)
{
    return length(q) - r;
}

float ff_sd_ring(vec2 q, float r)
{
    return abs(length(q) - r) - r * 0.25;
}

float ff_sd_capsule(vec2 q, float size)
{
    // Rotating capsule: SDF of a line segment of half-length `size`
    float a = iTime * 0.5;
    vec2 axis = vec2(cos(a), sin(a));
    float t = dot(q, axis);
    vec2 closest = axis * clamp(t, -size, size);
    return length(q - closest) - size * 0.3;
}

float ff_sd_star(vec2 q, float size)
{
    // 5-pointed star SDF (guarded denominator)
    const float N = 5.0;
    const float AN = 3.141592653589793 / N;
    float sn = sin(AN);
    float cn = cos(AN);
    float ang = atan(q.x, q.y);
    float ra = mod(ang, 2.0 * AN);
    ra = min(ra, 2.0 * AN - ra);
    float r = length(q);
    return (r * cn - size * sn) / max(cn * cn + r * r * sn * sn, 1e-4);
}

// --- pattern dispatch (driven by the `pattern` enum uniform) ---
float ff_shape(vec2 q, float size)
{
    if (pattern == 0)
    {
        // Blob: wobbled circle (deformed by noise)
        float w = ff_noise(q * 2.0 + iTime * 0.3);
        float r = size * (1.0 + 0.3 * w);
        return ff_sd_circle(q, r);
    }
    if (pattern == 1)
    {
        return ff_sd_ring(q, size);
    }
    if (pattern == 2)
    {
        return ff_sd_capsule(q, size);
    }
    return ff_sd_star(q, size);
}
