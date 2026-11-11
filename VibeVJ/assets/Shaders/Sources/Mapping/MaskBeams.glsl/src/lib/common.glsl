// --- MaskBeams: what every pass shares (the emitters, the surfaces, the colours of the beams) ---
#define MASK_AUTO 3
#include mapping.glsl
#include mask.glsl
#include beat.glsl
#include jfa.glsl

//@int min=1 max=8 value=4
uniform int beams;
//@enum options=(Bottom row, Top row, Left and right, Corners, Centre, Point A) value=0
uniform int emitter_layout;
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.1)
uniform vec2 point_a;         // Point A: where all beams start
//@slider min=-180.0 max=180.0 value=0.0
uniform float aim;            // degrees: turns every beam
//@slider min=0.0 max=360.0 value=40.0
uniform float fan;            // degrees: Centre and Point A spread their beams over this angle (Centre: 360 all around)
//@enum options=(Still, Sweep, Rotate, Step on pulse, Wander) value=1
uniform int motion;
//@slider min=0.0 max=360.0 value=50.0
uniform float sweep_range;    // degrees
//@slider min=0.0 max=2.0 value=0.125
uniform float sweep_speed;    // sweeps (Rotate: turns) per beat
//@slider min=0.0 max=1.0 value=0.25
uniform float sweep_phase;    // the beams sweep one after the other
//@enum options=(Mirrors, Glass, Absorbers) value=0
uniform int surfaces;         // what the white shapes of the mask do with a beam: reflect it, bend it (prisms) or stop it (a hot spot)
//@enum options=(Mirror, Absorb) value=1
uniform int frame_edges;      // the edge of the picture
//@int min=0 max=7 value=5
uniform int bounces;          // how often a beam is reflected or bent at most
//@slider min=0.0 max=1.0 value=0.8
uniform float reflectivity;   // the share of the light a mirror gives back
//@slider min=1.0 max=2.5 value=1.5
uniform float glass_index;    // the refractive index of Glass
//@slider min=0.0 max=0.3 value=0.0
uniform float dispersion;     // Glass: each beam splits into red, green and blue (three rays a beam)

//@enum options=(Single colour, Two colours, Rainbow, Cycle) value=2
uniform int color_mode;
//@rgb value=(0.2, 1.0, 0.3)
uniform vec3 color_a;
//@rgb value=(1.0, 0.1, 0.5)
uniform vec3 color_b;

// The rays traced in pass B: three a beam with dispersion
int bm_rays() { return clamp(beams, 1, 8) * (dispersion > 0.0 ? 3 : 1); }
int bm_beam_of(int ray) { return dispersion > 0.0 ? ray / 3 : ray; }

vec3 bm_beam_color(int b) {
    float n = float(clamp(beams, 1, 8));
    if (color_mode == 0) return color_a;
    if (color_mode == 1) return (b % 2 == 0) ? color_a : color_b;
    if (color_mode == 3) return mp_hue(iTime * 0.0625 + float(b) * 0.08);
    return mp_hue(float(b) / n);
}

// The colour of a ray: its beam's, or one channel of it with dispersion
vec3 bm_ray_color(int ray) {
    vec3 c = bm_beam_color(bm_beam_of(ray));
    if (dispersion <= 0.0) return c;
    int ch = ray % 3;
    float l = max(c.r, max(c.g, c.b));
    vec3 w = ch == 0 ? vec3(1.0, 0.05, 0.0) : (ch == 1 ? vec3(0.0, 1.0, 0.1) : vec3(0.05, 0.15, 1.0));
    return mix(w * l, w * c * 3.0, 0.3);
}
