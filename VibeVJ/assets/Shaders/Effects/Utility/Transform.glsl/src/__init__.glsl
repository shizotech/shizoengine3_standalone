//@settings dtype=float32 format=rgba
// --- Transform: crop, fit, move, scale, turn and tile a picture in one step (the Crop, Fit, Transform and Tile
// TOPs of TouchDesigner) ---
// In this order: the input is cropped, fitted into the picture (stretch, fit, fill or its own pixel size), moved,
// scaled and turned around the pivot, then repeated into tiles (with mirror, brick offset and gaps). What lies
// outside follows Edge. The input is read with its own bilinear filter, so a zoomed picture of a shader (whose
// textures are not filtered) stays smooth. Scroll and Spin move it with the beat (iTime counts beats in Sync).

uniform sampler2D input;

//@enum options=(Stretch, Fit, Fill, Pixel size) value=1
uniform int fit;                    // Fit: all of the input, with bars; Fill: no bars, cut; Pixel size: 1:1 pixels
//@slider min=0.0 max=1.0 value=0.0
uniform float crop_left;
//@slider min=0.0 max=1.0 value=0.0
uniform float crop_right;
//@slider min=0.0 max=1.0 value=0.0
uniform float crop_top;
//@slider min=0.0 max=1.0 value=0.0
uniform float crop_bottom;
//@slidervec2 min=(-1.0,-1.0) max=(1.0,1.0) value=(0.0,0.0)
uniform vec2 position;              // moves the picture, 1 = half the height
//@slider min=0.05 max=8.0 value=1.0
uniform float scale;
//@slidervec2 min=(0.1,0.1) max=(4.0,4.0) value=(1.0,1.0)
uniform vec2 stretch;               // scale of x and y on their own
//@slider min=-180.0 max=180.0 value=0.0
uniform float rotate;               // degrees
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 pivot;                 // the point of the picture that the scale and turn keep in place
//@button
uniform bool flip_x;
//@button
uniform bool flip_y;
//@int min=1 max=32 value=1
uniform int tiles_x;                // copies across the picture frame
//@int min=1 max=32 value=1
uniform int tiles_y;
//@enum options=(None, Mirror X, Mirror Y, Mirror both) value=0
uniform int tile_mirror;            // every second copy mirrored: seamless patterns
//@slider min=0.0 max=1.0 value=0.0
uniform float brick_offset;         // shifts every second row of copies by this share of a copy
//@slider min=0.0 max=0.5 value=0.0
uniform float tile_gap;             // space between copies, a share of a copy
//@enum options=(Transparent, Clamp, Repeat, Mirror) value=0
uniform int edge;                   // what is outside of the frame of the picture (Repeat / Mirror fill the screen)
//@slider min=0.0 max=0.2 value=0.0
uniform float feather;              // soft border of the frame and of the copies
//@slidervec2 min=(-2.0,-2.0) max=(2.0,2.0) value=(0.0,0.0)
uniform vec2 scroll;                // the picture moves inside its frame, frames a beat (with Edge Repeat / Mirror)
//@slider min=-90.0 max=90.0 value=0.0
uniform float spin;                 // degrees a beat
//@rgba value=(0.0, 0.0, 0.0, 1.0)
uniform vec4 background;            // where nothing is drawn; alpha 0 keeps it transparent for a Composite
//@button
uniform bool use_alpha;             // the alpha of the input cuts it out (many sources write 1 there, some 0: off)

// Bilinear read of the input (the textures of shaders are nearest)
vec4 readInput(vec2 uv) {
    ivec2 size = textureSize(input, 0);
    vec2 p = uv * vec2(size) - 0.5;
    ivec2 i = ivec2(floor(p));
    vec2 f = p - vec2(i);
    ivec2 hi = size - 1;
    vec4 a = texelFetch(input, clamp(i, ivec2(0), hi), 0);
    vec4 b = texelFetch(input, clamp(i + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(input, clamp(i + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(input, clamp(i + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// x in 0..1 after an edge mode; inside is 0 where the mode leaves the point out
float edgeWrap(float x, int mode, out float inside) {
    inside = 1.0;
    if (mode == 2)
        return fract(x);
    if (mode == 3) {
        float m = mod(x, 2.0);
        return m > 1.0 ? 2.0 - m : m;
    }
    if (mode == 0 && (x < 0.0 || x > 1.0))
        inside = 0.0;
    return clamp(x, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    float outAspect = res.x / res.y;
    vec2 inSize = vec2(max(textureSize(input, 0), ivec2(1)));
    vec2 cropLo = vec2(crop_left, crop_bottom);
    vec2 cropHi = max(vec2(1.0 - crop_right, 1.0 - crop_top), cropLo + 1e-3);
    vec2 cropSize = inSize * (cropHi - cropLo);              // pixels of the input that are left
    float inAspect = cropSize.x / cropSize.y;

    // the frame of the picture, in units where the output is outAspect x 1
    vec2 frame;
    if (fit == 0)
        frame = vec2(outAspect, 1.0);
    else if (fit == 1)
        frame = inAspect > outAspect ? vec2(outAspect, outAspect / inAspect) : vec2(inAspect, 1.0);
    else if (fit == 2)
        frame = inAspect > outAspect ? vec2(inAspect, 1.0) : vec2(outAspect, outAspect / inAspect);
    else
        frame = cropSize / res.y;

    // the output pixel in frame units around the pivot, the transform undone
    vec2 p = (fragCoord / res - 0.5) * vec2(outAspect, 1.0);
    vec2 pv = (pivot - 0.5) * frame;
    p -= position * 0.5 + pv;
    float a = -radians(rotate + spin * iTime);
    p = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y);
    p /= max(scale * stretch, vec2(1e-3));
    p += pv;
    vec2 f = p / frame + 0.5;                                 // 0..1 over the frame
    if (flip_x)
        f.x = 1.0 - f.x;
    if (flip_y)
        f.y = 1.0 - f.y;
    f -= scroll * iTime;

    float inX, inY;
    f = vec2(edgeWrap(f.x, edge, inX), edgeWrap(f.y, edge, inY));
    float mask = inX * inY;
    if (feather > 0.0 && edge < 2) {
        vec2 e = min(f, 1.0 - f);
        mask *= smoothstep(0.0, feather, e.x) * smoothstep(0.0, feather, e.y);
    }

    // tiles
    vec2 t = f * vec2(tiles_x, tiles_y);
    float row = floor(t.y);
    if (mod(row, 2.0) > 0.5)
        t.x += brick_offset;
    vec2 cell = floor(t);
    vec2 local = t - cell;
    if ((tile_mirror == 1 || tile_mirror == 3) && mod(cell.x, 2.0) > 0.5)
        local.x = 1.0 - local.x;
    if ((tile_mirror == 2 || tile_mirror == 3) && mod(cell.y, 2.0) > 0.5)
        local.y = 1.0 - local.y;
    if (tile_gap > 0.0) {
        float g = tile_gap * 0.5;
        vec2 inner = (local - g) / (1.0 - 2.0 * g);
        vec2 e = min(inner, 1.0 - inner);
        float soft = max(feather, 1e-4);
        mask *= smoothstep(0.0, soft, e.x) * smoothstep(0.0, soft, e.y) * step(0.0, min(e.x, e.y));
        local = clamp(inner, 0.0, 1.0);
    }

    vec4 src = readInput(mix(cropLo, cropHi, local));
    src.a = (use_alpha ? clamp(src.a, 0.0, 1.0) : 1.0) * mask;
    src.rgb *= src.a;
    // the picture over the background (premultiplied)
    vec4 col = vec4(src.rgb + background.rgb * background.a * (1.0 - src.a), src.a + background.a * (1.0 - src.a));
    fragColor = vec4(col.a > 0.0 ? col.rgb / col.a : vec3(0.0), col.a);
}
