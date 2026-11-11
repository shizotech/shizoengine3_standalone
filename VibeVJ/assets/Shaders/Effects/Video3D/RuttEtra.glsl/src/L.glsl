//@settings draw=quads count=lines*detail*3 blend=add dtype=float16 format=rgba
// --- RuttEtra, pass L: one quad a segment of a line (SHADER_GUIDE.MD, Point passes) ---
// mainPoint finds the line and the segment of the quad, reads the picture at both ends, lifts them, projects them
// and puts a quad around the segment; data carries the segment (half of it, in pixels from the middle) and its width.
// The first third of the ids are the rows, the rest the columns (Line mode Vertical / Grid): as many as fit the
// aspect of the picture, so the cells of the grid are square (up to twice Lines).
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D S;

// The picture along the line at uv, blurred by Smoothing in the direction of the line
vec3 picture(vec2 uv, vec2 along) {
    vec2 d = along * smoothing;
    vec3 c = texture(input, uv).rgb * 0.4 + (texture(input, uv - d).rgb + texture(input, uv + d).rgb) * 0.3;
    return clamp(c, 0.0, 1.0);
}

// A point of a line in the world: x -aspect .. aspect, y -1 .. 1, lifted by the picture
vec3 linePoint(vec2 uv, float lift, float aspect, bool column) {
    vec3 p = vec3((uv.x * 2.0 - 1.0) * aspect, uv.y * 2.0 - 1.0, 0.0);
    lift -= 0.45 * displacement;                    // mid grey stays in place, so a bright picture does not fly off
    // Up bends a row up and a column to the side (in the picture plane)
    vec3 up = column ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    if (displace_direction == 0)
        p += up * lift;
    else if (displace_direction == 1)
        p.z += lift;
    else
        p += (up + vec3(0.0, 0.0, 1.0)) * 0.7 * lift;
    return p;
}

void mainPoint(int id, inout vec4 position, inout float size_px, inout vec4 color, inout vec4 data) {
    int segs = max(detail, 2);
    int nl = max(lines, 2);
    int perSet = nl * segs;
    float aspect = iResolution.x / iResolution.y;
    int set = min(id / perSet, 1);
    if ((set == 0 && line_mode == 1) || (set == 1 && line_mode == 0))
        return;
    int rem = id - set * perSet;
    int k = rem / segs;
    int j = rem - k * segs;
    // rows: Lines; columns: as many as keep the cells square
    int count = set == 0 ? nl : clamp(int(float(nl) * aspect + 0.5), 2, 2 * nl);
    if (k >= count)
        return;

    vec4 lv = musicLevels(S);
    vec4 hit = musicHit(S);
    bool soundOn = musicSoundOn(S);

    // the line across the picture, rolling with Scroll; it fades in and out at the edges while it rolls
    float line = (float(k) + 0.5) / float(count) + scroll * iTime / float(count);
    float edge = 1.0;
    if (scroll != 0.0) {
        line = fract(line);
        edge = smoothstep(0.0, 0.6 / float(count), line) * smoothstep(1.0, 1.0 - 0.6 / float(count), line);
    }
    vec2 along = set == 0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    float s0 = float(j) / float(segs), s1 = float(j + 1) / float(segs);
    vec2 uv0 = set == 0 ? vec2(s0, line) : vec2(line, s0);
    vec2 uv1 = set == 0 ? vec2(s1, line) : vec2(line, s1);
    vec3 c0 = picture(uv0, along), c1 = picture(uv1, along);

    float disp = displacement * (1.0 + bass_displace * lv.x);
    float w0 = wave * musicWave(s0, soundOn) * 0.25, w1 = wave * musicWave(s1, soundOn) * 0.25;
    float l0 = liftOf(c0), l1 = liftOf(c1);
    float key0 = smoothstep(cutoff, cutoff + 0.04, lumaOf(c0)), key1 = smoothstep(cutoff, cutoff + 0.04, lumaOf(c1));
    if (cutoff <= 0.0) {
        key0 = 1.0;
        key1 = 1.0;
    }
    vec3 q0 = project(linePoint(uv0, l0 * disp + w0, aspect, set == 1), aspect);
    vec3 q1 = project(linePoint(uv1, l1 * disp + w1, aspect, set == 1), aspect);
    if (q0.z < 0.05 || q1.z < 0.05 || key0 + key1 <= 0.0)
        return;

    // the colour of the segment
    vec3 c = 0.5 * (c0 + c1);
    float lum = lumaOf(c);
    vec3 base = mix(vec3(lum), c, saturation_boost);
    vec3 col;
    if (color_mode == 1)
        col = mix(color_a, color_b, smoothstep(0.05, 0.9, 0.5 * (l0 + l1)));
    else if (color_mode == 2)
        col = color_a;
    else if (color_mode == 3)
        col = base * color_a * 2.0;
    else
        col = base / max(max(base.r, max(base.g, base.b)), 0.25) * 0.9;
    col = max(col, vec3(0.0));
    float bright = brightness * mix(1.0, 0.12 + 1.25 * lum, brightness_by_picture);
    // the beat: some lines flash (others a little)
    float rnd = musicHash01(k + set * 4099, int(hit.z));
    bright *= 1.0 + beat_flash * hit.x * (rnd < 0.3 ? 3.0 : 0.5);
    // far lines darker
    float zmid = 0.5 * (q0.z + q1.z);
    bright *= mix(1.0, smoothstep(camera_distance + 1.6, camera_distance - 1.2, zmid), depth_fade);
    bright *= edge * 0.5 * (key0 + key1);

    vec2 res = iResolution.xy;
    vec2 p0 = (q0.xy * 0.5 + 0.5) * res, p1 = (q1.xy * 0.5 + 0.5) * res;
    vec2 mid = 0.5 * (p0 + p1);
    vec2 half_ = 0.5 * (p1 - p0);
    float sigma = max(0.5 * thickness * res.y / 1080.0, 0.35);
    size_px = 2.0 * max(abs(half_.x), abs(half_.y)) + 6.0 * sigma + 2.0;
    position = vec4(mid / res * 2.0 - 1.0, 0.0, 1.0);
    // a thin line of less than a pixel is drawn one pixel wide and fainter
    float thin = min(1.0, 0.5 * thickness * res.y / 1080.0 / 0.35);
    color = vec4(col * bright * thin, 1.0);
    data = vec4(half_, sigma, 0.0);
}

// erf, good to 1e-4 (Abramowitz and Stegun 7.1.26 style approximation)
float erfApprox(float x) {
    float t = x * x;
    float a = 0.147;
    float v = sqrt(1.0 - exp(-t * (1.2732395 + a * t) / (1.0 + a * t)));
    return x < 0.0 ? -v : v;
}

// The segment as a soft line: a Gaussian across it, its integral along it (so segments add up without seams)
vec4 pointPixel(vec4 color, vec4 data, vec2 coord) {
    float size = 2.0 * max(abs(data.x), abs(data.y)) + 6.0 * data.z + 2.0;
    vec2 p = vec2(coord.x - 0.5, 0.5 - coord.y) * size;
    float len = length(data.xy);
    vec2 dir = len > 1e-4 ? data.xy / len : vec2(1.0, 0.0);
    float s = dot(p, dir);
    float r = dot(p, vec2(-dir.y, dir.x));
    float k = 0.70710678 / data.z;
    float across = exp(-0.5 * r * r / (data.z * data.z));
    float alongW = 0.5 * (erfApprox((len - s) * k) - erfApprox((-len - s) * k));
    return vec4(color.rgb * across * alongW, across * alongW);
}
