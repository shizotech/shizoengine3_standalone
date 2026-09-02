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

// Distance from point p to segment ab (kept from ShapeClone for symmetry)
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
    float b1 = (v2.x - v1.x) * (p.y - v1.y) - (v2.y - v1.y) * (p.x - v1.x);
    float b2 = (v3.x - v2.x) * (p.y - v2.y) - (v3.y - v2.y) * (p.x - v2.x);
    float b3 = (v1.x - v3.x) * (p.y - v3.y) - (v1.y - v3.y) * (p.x - v3.x);
    bool hasNeg = (b1 < 0.0) || (b2 < 0.0) || (b3 < 0.0);
    bool hasPos = (b1 > 0.0) || (b2 > 0.0) || (b3 > 0.0);
    float inside = (hasNeg && hasPos) ? -1.0 : 1.0;
    return inside * d;
}

// Distance along ray t*dir to segment ab (ray-segment intersection for the triangle)
float triRayDist(vec2 dir, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float det = ab.x * dir.y - ab.y * dir.x;
    if (abs(det) < 0.000001) {
        return 1e9;
    }
    float t = (a.y * ab.x - a.x * ab.y) / det;
    float s = (a.y * dir.x - a.x * dir.y) / det;
    if (t <= 0.0 || s < 0.0 || s > 1.0) {
        return 1e9;
    }
    return t;
}

// Radial boundary radius of an upward equilateral triangle in the direction dir (circumradius R)
float triBoundaryRadius(vec2 dir, float R) {
    vec2 v1 = vec2(0.0, R);
    vec2 v2 = vec2(R * cos(210.0 * PI / 180.0), R * sin(210.0 * PI / 180.0));
    vec2 v3 = vec2(R * cos(330.0 * PI / 180.0), R * sin(330.0 * PI / 180.0));
    float d1 = triRayDist(dir, v1, v2);
    float d2 = triRayDist(dir, v2, v3);
    float d3 = triRayDist(dir, v3, v1);
    return min(min(d1, d2), d3);
}

// Per-copy "fill ratio": radial distance from the copy center to the shape's
// boundary in the current direction, normalized by the boundary radius in that
// direction. Used to warp/compress the input into the shape outline.
float shapeFillRatio(vec2 uv, vec2 cellCenter, float R, int shape, float time) {
    vec2 c = uv - cellCenter;
    if (shape == 0) {
        // Original: no distortion (full box, ratio = 1.0)
        return 1.0;
    }
    float dist = length(c);
    if (shape == 1) {
        // Rund: circle of constant radius R
        return dist / R;
    }
    if (shape == 2) {
        // Wolke: animated wavy "cloud" blob (same wobble formula as the mask)
        float ang = atan(c.y, c.x);
        float wobble = R * (1.0 + 0.15 * sin(ang * 6.0 + time) + 0.10 * sin(ang * 3.0 - time * 1.3));
        return dist / wobble;
    }
    if (shape == 3) {
        // Dreieck: ray-cast from the center to the triangle boundary
        float ang = atan(c.y, c.x);
        vec2 dir = vec2(cos(ang), sin(ang));
        float bound = triBoundaryRadius(dir, R * 1.1);
        return dist / bound;
    }
    if (shape == 4) {
        // Oval: ellipse inscribed in the copy box (aspect-correct)
        vec2 boxHalf = vec2(R, R * video_aspect);
        float ang = atan(c.y, c.x);
        float ca = cos(ang);
        float sa = sin(ang);
        float e1 = boxHalf.y * ca;
        float e2 = boxHalf.x * sa;
        float bound = (boxHalf.x * boxHalf.y) / sqrt(e1 * e1 + e2 * e2);
        return dist / bound;
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
        float ratio = shapeFillRatio(uv, cellCenter, R, shape, iTime);
        // Warp: compress/stretch the input into the shape outline
        vec2 sampleUv = (uv - cellCenter) / boxW * ratio + vec2(0.5, 0.5);
        vec4 sample = texture(input, sampleUv);
        color = mix(color, sample, 1.0);
    }

    fragColor = color;
}
