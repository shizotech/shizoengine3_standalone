// ---- Projection mapping building blocks (#586): the mask and its calibration (the same in every asset) ----
// White in the mask picture is a surface / an object, black is free space. Link any picture into the port Mask:
// a PNG traced over a photo taken from the projector, the output of MapLab or MaskPrep, a camera.
#ifdef MASK_FROM_INPUT
#define MP_MASK_TEX input
uniform sampler2D input;   // MaskPrep: the picture the mask is made of
#else
#define MP_MASK_TEX mask
uniform sampler2D mask;    // white = surface / object, black = free
#endif

//@enum options=(Auto, Mask input, Demo facade, Demo objects, None) value=0
uniform int mask_source;   // Auto: the picture linked into Mask, else the demo shapes of the asset
//@enum options=(Brightness, Alpha, Red, Green, Blue) value=0
uniform int mask_channel;  // which channel is the mask: Brightness is the brightest channel; Alpha for a PNG with transparency
//@slider min=0.0 max=1.0 value=0.5
uniform float mask_threshold;
//@slider min=0.0 max=0.5 value=0.05
uniform float mask_softness;   // a soft threshold: 0 is a hard cut
//@button
uniform bool mask_invert;
//@slider min=0.0 max=32.0 value=0.0
uniform float mask_blur;       // pixels: smooths a noisy or jagged mask (a camera) before the threshold
//@slidervec2 min=(-0.5,-0.5) max=(0.5,0.5) value=(0.0,0.0)
uniform vec2 mask_offset;      // calibration: moves the mask against the picture (share of width / height)
//@slider min=0.25 max=4.0 value=1.0
uniform float mask_scale;
//@slider min=-180.0 max=180.0 value=0.0
uniform float mask_rotation;   // degrees
//@enum options=(None, Vertical, Horizontal, Both) value=0
uniform int mask_flip;         // a PNG linked straight into Mask arrives upside down: Vertical (or Flip Y of the picture)

// Is a picture linked into Mask? Only a pass that reads no other texture may ask (pass M, or pass N with
// mp_mask_mode_pass): an unlinked sampler reads texture unit 0, or the unit it had when it was last linked, and in a
// pass with other inputs that unit holds one of them. textureSize() then saw that texture, and Auto took it for the
// mask: RegionChase and MaskRain covered most of the picture, EdgeSweep took the bright parts of its input for a mask
// (#880, 2026-11-01). A pass with other inputs takes the answer of pass N instead: mp_mask_mode_from(N) first thing in
// mainImage. A linked Mask gets a texture unit of its own, so reading the picture itself is safe in every pass.
bool mp_mask_linked() { return textureSize(MP_MASK_TEX, 0).x > 1; }

int mp_mode_given = 0;   // 0: this pass asks itself, else the mode pass N found

// 1 the picture, 2 demo facade, 3 demo objects, 4 none, 5 Mask input with nothing linked (an empty mask)
int mp_mask_mode() {
    if (mp_mode_given != 0) return mp_mode_given;
    if (mask_source == 0) return mp_mask_linked() ? 1 : MASK_AUTO;
    return mask_source;
}

// Pass N (one pixel, rendersize=(1,1), no input but Mask): the mode in r
vec4 mp_mask_mode_pass() {
    int mode = mp_mask_mode();
    if (mode == 1 && !mp_mask_linked()) mode = 5;
    return vec4(float(mode), 0.0, 0.0, 1.0);
}

// Every pass that reads the mask and has other inputs: the mode as pass N found it
void mp_mask_mode_from(sampler2D n) {
    mp_mode_given = int(texelFetch(n, ivec2(0, 0), 0).r + 0.5);
}

// The calibration: from the uv of the picture to the uv of the mask
vec2 mp_mask_uv(vec2 uv) {
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = uv - 0.5 - mask_offset;
    p.x *= a;
    p = mp_rot(-radians(mask_rotation)) * p / max(mask_scale, 0.01);
    p.x /= a;
    p += 0.5;
    if (mask_flip == 1 || mask_flip == 3) p.y = 1.0 - p.y;
    if (mask_flip == 2 || mask_flip == 3) p.x = 1.0 - p.x;
    return p;
}

// The demo shapes, in mask uv; 1 inside. aa: the width of the soft edge in units of the height
float mp_demo_facade(vec2 uv, float aa) {
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = vec2((uv.x - 0.5) * a, uv.y - 0.5);
    float d = 1e5;
    // 5 x 3 windows, the middle one of the lowest row is a door with an arch
    for (int j = 0; j < 3; j++) {
        for (int i = 0; i < 5; i++) {
            vec2 c = vec2((float(i) - 2.0) * 0.27, 0.27 - float(j) * 0.25);
            if (j == 2 && i == 2) continue;
            d = min(d, mp_sd_box(p - c, vec2(0.075, 0.085), 0.012));
        }
    }
    vec2 door = p - vec2(0.0, -0.33);
    d = min(d, min(mp_sd_box(door, vec2(0.085, 0.13), 0.0), length(door - vec2(0.0, 0.13)) - 0.085));
    d = min(d, length(p - vec2(0.0, 0.43)) - 0.045);   // a round window under the roof
    return clamp(0.5 - d / max(aa, 1e-4), 0.0, 1.0);
}

float mp_demo_objects(vec2 uv, float aa) {
    float a = iResolution.x / max(iResolution.y, 1.0);
    vec2 p = vec2((uv.x - 0.5) * a, uv.y - 0.5);
    float d = length(p - vec2(-0.42, -0.02)) - 0.16;                              // a ball
    d = min(d, mp_sd_box(mp_rot(radians(-12.0)) * (p - vec2(0.05, -0.2)), vec2(0.1, 0.17), 0.01));  // a box
    d = min(d, mp_sd_tri(p - vec2(0.5, 0.05), 0.15));                                  // a pyramid
    d = min(d, mp_sd_box(p - vec2(0.02, 0.22), vec2(0.22, 0.018), 0.008));             // a shelf
    d = min(d, mp_sd_box(p - vec2(0.78, -0.3), vec2(0.035, 0.2), 0.0));                // a pillar
    return clamp(0.5 - d / max(aa, 1e-4), 0.0, 1.0);
}

float mp_mask_channel(vec4 c) {
    if (mask_channel == 1) return c.a;
    if (mask_channel == 2) return c.r;
    if (mask_channel == 3) return c.g;
    if (mask_channel == 4) return c.b;
    return max(c.r, max(c.g, c.b));   // a grey PNG arrives as red only
}

// The mask before the threshold at a uv of the picture (calibration applied); outside the mask picture it is 0
float mp_mask_raw(vec2 uv) {
    int mode = mp_mask_mode();
    if (mode >= 4) return 0.0;
    vec2 m = mp_mask_uv(uv);
    float aa = 1.5 / max(iResolution.y, 1.0);
    if (mode == 2) return mp_demo_facade(m, aa);
    if (mode == 3) return mp_demo_objects(m, aa);
    if (m.x < 0.0 || m.y < 0.0 || m.x > 1.0 || m.y > 1.0) return 0.0;
    return mp_mask_channel(mp_bilinear_uv(MP_MASK_TEX, m));
}

// The mask: blur, threshold, invert. 0..1, 1 = surface / object
float mp_mask(vec2 uv) {
    float raw = mp_mask_raw(uv);
    if (mask_blur > 0.25) {
        // 12 taps on two rings plus the middle, radius in pixels of the full picture
        vec2 r = vec2(mask_blur) / (iResolution.xy / PASS_SCALE);
        float sum = raw * 2.0;
        float wsum = 2.0;
        for (int i = 0; i < 12; i++) {
            float ang = float(i) * (MP_TAU / 12.0) + (i >= 6 ? 0.5 : 0.0);
            float rad = i < 6 ? 0.5 : 1.0;
            vec2 o = vec2(cos(ang), sin(ang)) * rad * r;
            float w = i < 6 ? 1.5 : 1.0;
            sum += mp_mask_raw(uv + o) * w;
            wsum += w;
        }
        raw = sum / wsum;
    }
    float s = max(mask_softness, 0.002);
    float m = smoothstep(mask_threshold - s, mask_threshold + s, raw);
    return mask_invert ? 1.0 - m : m;
}
