//@settings dtype=float32 format=rgba

//@enum options=(Original,Rund,Wolke,Dreieck,Oval)
uniform int shape;

//@int min=1 max=64 value=4
uniform int copy_count;

//@float min=0.05 max=1.0 value=0.3
uniform float copy_size;

//@float min=0.0 max=0.5 value=0.05
uniform float copy_spacing;

//@float min=-1.0 max=1.0 value=0.0
uniform float offset_x;

//@float min=-1.0 max=1.0 value=0.0
uniform float offset_y;

//@float min=0.0 max=1.0 value=0.0
uniform float mask_left;

//@float min=0.0 max=1.0 value=1.0
uniform float mask_right;

//@float min=0.0 max=1.0 value=0.0
uniform float mask_top;

//@float min=0.0 max=1.0 value=1.0
uniform float mask_bottom;

//@float min=0.5 max=2.5 value=1.777
uniform float video_aspect;

//@rgb value=(0.05,0.05,0.1)
uniform vec3 bg_color;

uniform sampler2D input;

#define PI 3.14159265359

// Distance from point p to segment ab (for triangle edge AA)
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float t = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * t);
}

// Signed distance to an upward-pointing equilateral triangle centered at the origin (circumradius R)
float triDist(vec2 p, float R) {
    vec2 v1 = vec2(0.0, R);
    vec2 v2 = vec2(R * cos(210.0 * PI / 180.0), R * sin(210.0 * PI / 180.0));
    vec2 v3 = vec2(R * cos(330.0 * PI / 180.0), R * sin(330.0 * PI / 180.0));
    float d1 = segDist(p, v1, v2);
    float d2 = segDist(p, v2, v3);
    float d3 = segDist(p, v3, v1);
    float d = min(min(d1, d2), d3);
    // Inside-test via three half-planes
    float b1 = (v2.x - v1.x) * (p.y - v1.y) - (v2.y - v1.y) * (p.x - v1.x);
    float b2 = (v3.x - v2.x) * (p.y - v2.y) - (v3.y - v2.y) * (p.x - v2.x);
    float b3 = (v1.x - v3.x) * (p.y - v3.y) - (v1.y - v3.y) * (p.x - v3.x);
    bool hasNeg = (b1 < 0.0) || (b2 < 0.0) || (b3 < 0.0);
    bool hasPos = (b1 > 0.0) || (b2 > 0.0) || (b3 > 0.0);
    float inside = (hasNeg && hasPos) ? -1.0 : 1.0;
    return inside * d;
}

// Per-copy shape mask. uv = screen uv, cellCenter = copy center (uv space), R = half copy size (uv units).
float shapeMask(vec2 uv, vec2 cellCenter, float R, int shape, float time) {
    if (shape == 0) {
        // Original: no distortion, fill the whole copy box (rectangle)
        return 1.0;
    }
    vec2 c = uv - cellCenter;
    if (shape == 1) {
        // Rund: a true screen-space circle of radius R
        float d = length(c) / R;
        return 1.0 - smoothstep(0.98, 1.0, d);
    }
    if (shape == 2) {
        // Wolke: animated wavy "cloud" blob
        float ang = atan(c.y, c.x);
        float wobble = R * (1.0 + 0.15 * sin(ang * 6.0 + time) + 0.10 * sin(ang * 3.0 - time * 1.3));
        float d = length(c);
        return 1.0 - smoothstep(wobble - 0.02, wobble, d);
    }
    if (shape == 3) {
        // Dreieck: upward equilateral triangle
        float d = triDist(c, R * 1.1);
        return 1.0 - smoothstep(-0.02, 0.02, d);
    }
    if (shape == 4) {
        // Oval: ellipse inscribed in the copy box (aspect-correct)
        vec2 boxHalf = vec2(R, R * video_aspect);
        vec2 q = c / boxHalf;
        float d = length(q);
        return 1.0 - smoothstep(0.98, 1.0, d);
    }
    return 1.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Mask region check: only render copies within [mask_left, mask_right] x [mask_top, mask_bottom]
    bool inMaskRegion = (uv.x >= mask_left && uv.x <= mask_right && uv.y >= mask_top && uv.y <= mask_bottom);

    float aspect = video_aspect;
    float R = copy_size * 0.5;

    // Evenly distributed grid of copies, shifted by offset_x / offset_y
    int cols = max(1, int(round(sqrt(float(copy_count)))));
    int rows = int(ceil(float(copy_count) / float(cols)));
    float pitchX = copy_size + copy_spacing;
    float pitchY = copy_size * aspect + copy_spacing;
    float gridW = float(cols) * pitchX;
    float gridH = float(rows) * pitchY;
    vec2 gridOrigin = vec2(0.5 + offset_x - gridW * 0.5, 0.5 + offset_y - gridH * 0.5);

    vec2 rel = uv - gridOrigin;
    int ci = int(floor(rel.x / pitchX));
    int ri = int(floor(rel.y / pitchY));
    bool inCopy = (ci >= 0 && ci < cols && ri >= 0 && ri < rows && ri * cols + ci < copy_count);

    // Outside any copy -> background color
    vec4 color = vec4(bg_color, 1.0);

    if (inCopy && inMaskRegion) {
        vec2 cellCenter = gridOrigin + vec2((float(ci) + 0.5) * pitchX, (float(ri) + 0.5) * pitchY);
        vec2 boxW = vec2(copy_size, copy_size * aspect);
        vec2 sampleUv = (uv - cellCenter) / boxW + vec2(0.5, 0.5);
        vec4 sample = texture(input, sampleUv);
        float m = shapeMask(uv, cellCenter, R, shape, iTime);
        color = mix(color, sample, m);
    }

    fragColor = color;
}
