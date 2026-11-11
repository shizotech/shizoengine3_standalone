//@settings dtype=float32 format=rgba
// --- MaskRipples (#586, projection mapping building blocks: simulations in the mask) ---
// Water in the surfaces of the mask (each window a pool) or around the objects (stones in a pond): the wave equation
// on half the size (pass W) with the outline of the mask as the shore, stirred by rain, by a drop at each pulse, by
// waves that leave the shores, by points that swim through it and by a picture (its motion or its bright parts).
// Seen as water over a picture (refraction, caustics, a highlight), as the caustic light alone (to light a real
// surface like the bottom of a pool), as contour lines, or as the height.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D W;
uniform sampler2D M;
uniform sampler2D T;
uniform sampler2D I;          // is a picture linked (pass I): not textureSize() here, this pass has other inputs (#880)

//@enum options=(Water, Caustic light, Contour lines, Height) value=0
uniform int look;
//@enum options=(Picture, Tiles, Colour) value=0
uniform int floor_look;       // what is under the water: the picture of the port Picture (tiles while none is linked)
//@slider min=0.0 max=200.0 value=45.0
uniform float refraction;     // pixels the floor moves under a slope
//@slider min=0.0 max=8.0 value=1.6
uniform float caustics;
//@slider min=0.5 max=4.0 value=1.6
uniform float caustic_sharpness;
//@rgb value=(0.85, 0.95, 1.0)
uniform vec3 caustic_color;
//@slider min=0.0 max=4.0 value=1.0
uniform float highlight;      // the light reflected on the waves
//@slider min=-180.0 max=180.0 value=135.0
uniform float light_angle;    // degrees: where the light comes from
//@rgb value=(0.1, 0.45, 0.6)
uniform vec3 water_color;
//@slider min=0.0 max=1.0 value=0.45
uniform float water_tint;
//@rgb value=(0.75, 0.85, 0.9)
uniform vec3 floor_color;
//@slider min=0.0 max=4.0 value=0.6
uniform float foam;           // white at the shore where the waves are high
//@int min=1 max=40 value=10
uniform int contour_levels;   // Contour lines: lines per unit of height
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;
//@enum options=(Black, Colour, Picture, Transparent) value=0
uniform int land_view;        // what is not water shows: on a real object Black keeps it dark
//@rgb value=(0.12, 0.12, 0.14)
uniform vec3 land_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

float hgt(vec2 pos) { return mp_bilinear(W, pos).r; }

vec3 floor_at(vec2 uv) {
    bool linked = texelFetch(I, ivec2(0, 0), 0).r > 0.5;
    if (floor_look == 0 && linked) return texture(picture, clamp(uv, 0.0, 1.0)).rgb;
    if (floor_look == 2) return floor_color;
    // tiles: 48 px with grout
    vec2 px = uv * iResolution.xy / (48.0 * iResolution.y / 1080.0);
    vec2 f = abs(fract(px) - 0.5);
    float grout = smoothstep(0.44, 0.48, max(f.x, f.y));
    float shade = 0.9 + 0.1 * mp_rand2(ivec2(floor(px)));
    return mix(floor_color * shade, floor_color * 0.55, grout);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 wres = vec2(textureSize(W, 0));
    vec2 wp = uv * wres;
    float h = hgt(wp);
    float hx = hgt(wp + vec2(1.0, 0.0)) - hgt(wp - vec2(1.0, 0.0));
    float hy = hgt(wp + vec2(0.0, 1.0)) - hgt(wp - vec2(0.0, 1.0));
    vec2 slope = vec2(hx, hy) * 0.5;
    vec3 n = normalize(vec3(-slope * 1.5, 1.0));

    // the water share at full size: the mask itself, or the simulation's when the mask is blurred
    // the mask from the passes (M, the jump flood), not from the port: in the main pass the unlinked port Mask was seen
    // reading another texture (#586)
    float m = mp_bilinear_uv(M, uv).r;
    float wet = rp_water_of(m);

    vec2 ruv = uv - slope * refraction / iResolution.xy;
    vec3 rgb;
    // caustics: light gathers under the crests (where the surface curves down); read at the refracted place
    vec2 cp = ruv * wres;
    float lap = hgt(cp + vec2(2.0, 0.0)) + hgt(cp - vec2(2.0, 0.0)) + hgt(cp + vec2(0.0, 2.0)) + hgt(cp - vec2(0.0, 2.0)) - 4.0 * hgt(cp);
    float caus = pow(clamp(-lap * 0.6, 0.0, 4.0), caustic_sharpness) * caustics;
    float la = radians(light_angle);
    vec3 L = normalize(vec3(cos(la), sin(la), 1.2));
    vec3 Hv = normalize(L + vec3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(n, Hv), 0.0), 90.0) * highlight * 3.0;

    if (look == 1) {
        rgb = caustic_color * (caus * 1.5 + 0.06 * caustics) + vec3(spec * 0.3);
    } else if (look == 2) {
        float lv = h * float(contour_levels);
        float k = abs(fract(lv) - 0.5);
        float w = fwidth(lv);
        float line = 1.0 - smoothstep(0.0, max(w * 1.5, 0.02), 0.5 - k);
        rgb = mix(water_color * 0.15, caustic_color, line * clamp(abs(h) * 4.0, 0.0, 1.0)) + vec3(spec * 0.2);
    } else if (look == 3) {
        rgb = vec3(0.5 + h * 0.5);
    } else {
        vec3 fl = floor_at(ruv);
        rgb = mix(fl, fl * water_color * 2.0, water_tint);
        rgb += caustic_color * caus * 0.5;
        rgb += vec3(spec);
        // the edge of the water: foam where the waves are high near the shore
        float shore_d = 0.0;
        for (int k = 0; k < 6; k++) {
            float a = float(k) * (MP_TAU / 6.0);
            shore_d += rp_water_of(mp_bilinear(M, uv * vec2(textureSize(M, 0)) + vec2(cos(a), sin(a)) * 3.0).r);
        }
        float near = clamp(1.0 - shore_d / 6.0, 0.0, 1.0);
        rgb = mix(rgb, vec3(1.0), clamp(foam * near * (abs(h) * 2.0 + 0.15), 0.0, 1.0));
    }
    rgb *= brightness;

    float alpha = 1.0;
    vec3 land = land_view == 1 ? land_color : (land_view == 2 ? floor_at(uv) : vec3(0.0));
    if (land_view == 3) alpha = wet;
    rgb = mix(land, rgb, wet);

    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * m);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
