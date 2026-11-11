//@settings draw=quads count=columns*rows blend=alpha dtype=float16 format=rgba
// --- Instancer, pass I: one quad a copy (SHADER_GUIDE.MD, Point passes) ---
// mainPoint runs for the corners of each copy: it finds the cell of the copy, reads the input picture there, places
// the copy (layout, depth, camera) and gives its size, colour and turn; pointPixel cuts the shape out of the quad.
#include lib/common.glsl

// The view: q is a world point turned into the camera's frame (the camera looks along -z)
vec3 toView(vec3 p) {
    float yaw = radians(camera_turn + camera_spin * iTime);
    float pitch = -radians(camera_tilt);
    p.xz = vec2(cos(yaw) * p.x - sin(yaw) * p.z, sin(yaw) * p.x + cos(yaw) * p.z);
    p.yz = vec2(cos(pitch) * p.y - sin(pitch) * p.z, sin(pitch) * p.y + cos(pitch) * p.z);
    return p;
}

void mainPoint(int id, inout vec4 position, inout float size_px, inout vec4 color, inout vec4 data) {
    int cols = max(columns, 1);
    int rws = max(rows, 1);
    if (id >= cols * rws)
        return;
    float aspect = iResolution.z;
    bool flat_view = view == 1;

    // the order of the copies: the far ones first, so the near ones cover them
    int a = id % cols;
    int b = id / cols;
    if (!flat_view && layout_mode != 3 && layout_mode != 4) {
        vec3 gx = toView(vec3(1.0, 0.0, 0.0));
        vec3 gy = toView(vec3(0.0, 1.0, 0.0));
        if (abs(gx.z) > abs(gy.z)) {
            a = id / rws;
            b = id % rws;
        }
        if (gx.z < 0.0)
            a = cols - 1 - a;
        if (gy.z < 0.0)
            b = rws - 1 - b;
    }
    vec2 cell = (vec2(a, b) + 0.5) / vec2(cols, rws);       // 0..1 over the layout

    vec3 pos;
    vec3 normal = vec3(0.0, 0.0, 1.0);
    vec2 uv;
    float cellSize;
    if (layout_mode == 0 || layout_mode == 1) {
        // Grid / Hex grid: over the picture
        vec2 c = cell;
        if (layout_mode == 1 && (b & 1) == 1)
            c.x += 0.5 / float(cols);
        pos = vec3((c * 2.0 - 1.0) * vec2(aspect, 1.0), 0.0);
        uv = c;
        cellSize = min(2.0 * aspect / float(cols), 2.0 / float(rws));
    } else if (layout_mode == 2) {
        // Circle: columns go around, rows go out
        float ang = cell.x * 2.0 * PI;
        float r = cell.y;
        pos = vec3(cos(ang) * r, sin(ang) * r, 0.0);
        uv = vec2(pos.x / aspect, pos.y) * 0.5 + 0.5;
        cellSize = min(1.0 / float(rws), 2.0 * PI * r / float(cols)) * 1.2;
    } else if (layout_mode == 3) {
        // Sphere: the picture wrapped around a ball
        float lon = cell.x * 2.0 * PI;
        float lat = (cell.y - 0.5) * PI;
        normal = vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon));
        pos = normal * 0.65;
        uv = cell;
        cellSize = min(2.0 * PI * 0.65 * cos(lat) / float(cols), PI * 0.65 / float(rws)) * 1.1;
    } else if (layout_mode == 4) {
        // Cylinder: the picture wrapped around a drum
        float ang = cell.x * 2.0 * PI;
        normal = vec3(sin(ang), 0.0, cos(ang));
        pos = normal * 0.65 + vec3(0.0, cell.y * 1.6 - 0.8, 0.0);
        uv = cell;
        cellSize = min(2.0 * PI * 0.65 / float(cols), 1.6 / float(rws));
    } else {
        // Scatter: every copy at its own random place
        vec2 h = vec2(hash12(vec2(float(id), 3.0)), hash12(vec2(float(id), 11.0)));
        pos = vec3((h * 2.0 - 1.0) * vec2(aspect, 1.0), 0.0);
        uv = h;
        cellSize = min(2.0 * aspect / float(cols), 2.0 / float(rws));
    }

    vec3 pix = textureLod(input, uv, 0.0).rgb;
    float luma = luminance(pix);
    if (luma < threshold)
        return;
    float v = clamp(driveValue(pix, size_by) * value_gain, 0.0, 1.0);
    float pulse = 1.0 + beat_pulse * 0.6 * pow(1.0 - fract(iTime), 4.0);
    float s = cellSize * size * mix(min_size, 1.0, v) * pulse;
    pos += normal * depth * v * (flat_view ? 0.0 : 1.0);

    float scale;
    if (flat_view) {
        position = vec4(pos.x / aspect * zoom, pos.y * zoom, 0.0, 1.0);
        scale = zoom;
    } else {
        vec3 q = toView(pos);
        if (blend == 0 && (layout_mode == 3 || layout_mode == 4) && toView(normal).z < -0.05)
            return;                                          // the back of the ball / drum
        float z = camera_distance - q.z;
        if (z < 0.05)
            return;
        float focal = camera_distance * zoom;
        position = vec4(q.x * focal / z / aspect, q.y * focal / z, 0.0, 1.0);
        scale = focal / z;
    }
    size_px = s * scale * iResolution.y * 0.5;

    vec3 tint;
    if (color_mode == 0)
        tint = pix;
    else if (color_mode == 1)
        tint = mix(color_a, color_b, luma);
    else if (color_mode == 2)
        tint = color_a;
    else
        tint = pix * color_a;
    color = vec4(tint * opacity, blend == 1 ? 0.0 : opacity);
    if (blend == 1 && tint == vec3(0.0))
        color = vec4(0.0);
    data = vec4(radians(rotate + rotate_by * v + spin * iTime), size_px, 0.0, 0.0);
}

vec4 pointPixel(vec4 color, vec4 data, vec2 coord) {
    vec2 p = coord * 2.0 - 1.0;
    p.y = -p.y;
    float cs = cos(data.x);
    float sn = sin(data.x);
    p = vec2(cs * p.x + sn * p.y, -sn * p.x + cs * p.y);
    float d = shapeDistance(p);
    float fw = 2.0 / max(data.y, 1.0);                       // a pixel, in the units of p
    float a = 1.0 - smoothstep(-fw, fw, d);
    if (outline > 0.0)
        a *= smoothstep(-fw, fw, d + outline * 2.0);
    return color * a;
}
