//@settings draw=points count=columns*rows blend=add dtype=float16 format=rgba
// --- PointCloud, pass P: one point a cell of the picture (SHADER_GUIDE.MD, Point passes) ---
// mainPoint reads the picture at the cell (jittered), pushes the point to its depth, adds the drift and the burst of
// the beat, projects it and sizes it by the distance; pointPixel cuts the Point shape out.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D S;

// The burst after a hit, t seconds ago: out, back, a small overshoot, settled. 0 before the hit, peak about 1
float burst(float t) {
    if (t <= 0.0)
        return 0.0;
    float w = MUSIC_TAU * spring;
    return sin(w * t) * exp(-t * 1.6 * spring) * 1.6;
}

void mainPoint(int id, inout vec4 position, inout float size_px, inout vec4 color, inout vec4 data) {
    int cols = max(columns, 1), rws = max(rows, 1);
    if (id >= cols * rws)
        return;
    int cx = id % cols, cy = id / cols;
    float aspect = iResolution.x / iResolution.y;
    float r1 = musicHash01(cx, cy), r2 = musicHash01(cx + 7919, cy), r3 = musicHash01(cx, cy + 7919);
    vec2 uv = (vec2(cx, cy) + 0.5 + (vec2(r1, r2) - 0.5) * jitter) / vec2(cols, rws);
    vec3 c = clamp(texture(input, uv).rgb, 0.0, 1.0);
    float lum = lumaOf(c);
    if (threshold > 0.0 && lum < threshold)
        return;

    vec4 lv = musicLevels(S);
    vec4 hit = musicHit(S);
    float d = depthOf(c) - 0.5;
    vec3 p = vec3((uv.x * 2.0 - 1.0) * aspect, uv.y * 2.0 - 1.0, d * depth * (1.0 + bass_depth * lv.x));

    // the drift: a slow flow of sines
    float t = iTime * 0.25;
    p += turbulence * 0.12 * vec3(sin(p.y * 3.1 + t * 2.0 + r3 * 2.0), sin(p.z * 2.7 + p.x * 1.3 - t * 1.7),
                                  sin(p.x * 2.3 + t * 1.3 + r1)) ;

    // the burst: it starts in the middle and runs out with Explode spread
    float radius = length(vec2((uv.x - 0.5) * aspect, uv.y - 0.5));
    float e = explode * burst(hit.y - explode_spread * 0.5 * radius) * (0.4 + 0.6 * r3);
    vec3 dir;
    if (explode_mode == 1)
        dir = normalize(vec3(p.xy, 0.3 * d) + 1e-4);
    else if (explode_mode == 2)
        dir = vec3(0.0, 0.0, 1.0) * (0.5 + r1);
    else if (explode_mode == 3)
        dir = normalize(vec3(-p.y, p.x, 0.0) + 1e-4) + vec3(0.0, 0.0, r2 - 0.5);
    else {
        float a = MUSIC_TAU * r1, z = r2 * 2.0 - 1.0;
        dir = vec3(sqrt(1.0 - z * z) * vec2(cos(a), sin(a)), z);
    }
    p += dir * e * 0.5;

    vec3 q = project(p, aspect);
    if (q.z < 0.05)
        return;

    // colour
    vec3 base = mix(vec3(lum), c, saturation_boost);
    vec3 col;
    if (color_mode == 1)
        col = mix(color_a, color_b, smoothstep(-0.5, 0.5, d));
    else if (color_mode == 2)
        col = color_a;
    else if (color_mode == 3)
        col = base * color_a * 2.0;
    else
        col = base / max(max(base.r, max(base.g, base.b)), 0.25) * 0.9;
    col = max(col, vec3(0.0)) * brightness * mix(1.0, 0.12 + 1.25 * lum, brightness_by_picture);
    col *= 1.0 + beat_flash * hit.x * (r2 < 0.25 ? 2.5 : 0.4);
    col *= mix(1.0, smoothstep(camera_distance + 1.6, camera_distance - 1.2, q.z), depth_fade);

    float scale = iResolution.y / 1080.0;
    size_px = point_size * scale * camera_distance / q.z * mix(1.0, 0.35 + 1.3 * lum, size_by_brightness);
    size_px = min(size_px, 64.0);
    position = vec4(q.xy, 0.0, 1.0);
    color = vec4(col, 1.0);
}

vec4 pointPixel(vec4 color, vec4 data, vec2 coord) {
    vec2 d = coord * 2.0 - 1.0;
    float r = length(d);
    float a;
    if (point_shape == 1)
        a = 1.0 - smoothstep(0.8, 1.0, r);
    else if (point_shape == 2)
        a = 1.0;
    else if (point_shape == 3)
        a = smoothstep(0.45, 0.65, r) * (1.0 - smoothstep(0.8, 1.0, r));
    else
        a = exp(-2.2 * r * r) * (1.0 - smoothstep(0.85, 1.0, r));
    return color * a;
}
