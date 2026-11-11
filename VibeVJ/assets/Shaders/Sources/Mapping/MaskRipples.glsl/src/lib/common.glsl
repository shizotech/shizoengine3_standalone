// --- MaskRipples: what every pass shares (the controls of the water, where the water is) ---
#define MASK_AUTO 2
#include mapping.glsl
#include mask.glsl
#include beat.glsl

uniform sampler2D picture;    // optional: the picture under the water (refracted), and / or what stirs it

//@enum options=(In the surfaces, Around the objects, Everywhere) value=0
uniform int water_place;      // In the surfaces: each white shape is a pool (the windows). Around: the objects stand in the water
//@enum options=(Reflect, Fixed, Soft) value=0
uniform int shore;            // a wave at the shoreline bounces back, bounces back upside down, or runs out
//@slider min=0.05 max=1.0 value=0.7
uniform float wave_speed;
//@slider min=0.0 max=0.05 value=0.006
uniform float damping;        // the waves calm down
//@slider min=0.0 max=2.0 value=0.12
uniform float rain;           // drops a frame
//@slider min=1.0 max=60.0 value=7.0
uniform float drop_size;      // pixels
//@slider min=0.0 max=4.0 value=1.0
uniform float drop_strength;
//@enum options=(Big drop, Waves from the shores, Rain burst, Nothing) value=0
uniform int pulse_action;     // what a pulse does (Pulse every, Trigger)
//@slider min=0.0 max=4.0 value=1.5
uniform float pulse_strength;
//@enum options=(Off, Motion, Brightness) value=0
uniform int picture_stir;     // the picture stirs the water: Motion (where it changes: a camera of people), Brightness (bright parts press in)
//@slider min=0.0 max=4.0 value=1.0
uniform float stir_amount;
//@slider min=0.0 max=2.0 value=0.3
uniform float wind;           // small waves all over, as from wind: the caustics get the net of a pool
//@slider min=4.0 max=120.0 value=30.0
uniform float wind_scale;     // pixels: the size of the wind waves
//@int min=0 max=6 value=0
uniform int swimmers;         // points that move through the water and leave a wake
//@slider min=0.0 max=2.0 value=0.3
uniform float swimmer_speed;

// The water (1) or land (0) of a mask value; without a mask the water is everywhere
float rp_water_of(float m) {
    if (water_place == 2 || mp_mask_mode() == 4) return 1.0;
    return water_place == 0 ? m : 1.0 - m;
}

// The place of swimmer i at time t (uv)
vec2 rp_swimmer(int i, float t) {
    float fi = float(i);
    float s = t * swimmer_speed * 0.15;
    return vec2(mp_vnoise(vec2(fi * 17.3 + 2.0, s)), mp_vnoise(vec2(fi * 9.1 + 50.0, s * 1.1))) * 1.3 - 0.15;
}

float rp_luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
