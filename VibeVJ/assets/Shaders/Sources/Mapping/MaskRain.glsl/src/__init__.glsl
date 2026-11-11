//@settings dtype=float32 format=rgba
// --- MaskRain (#586, projection mapping building blocks) ---
// Rain, snow, sparks or drops of light that fall onto the mapped objects, stop on their top surfaces and splash
// there; nothing falls under an overhang. Where a drop hits comes from a fall map (passes M, H1..H10 at half size:
// for every texel the distance along the fall to the next surface, by doubling), the drops themselves are
// worked out per pixel (no state), so they keep their place on a jump of the timeline. A pulse can flash the
// surfaces like lightning.
#define PASS_SCALE 1.0
#include lib/common.glsl

uniform sampler2D M;
uniform sampler2D N;          // which mask (pass N): see mp_mask_mode_from in lib/mask.glsl
uniform sampler2D H10;
uniform sampler2D T;

//@enum options=(Rain, Snow, Sparks, Light drops) value=0
uniform int kind;
//@slider min=0.0 max=1.0 value=0.6
uniform float density;
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;          // screen heights per beat (Sync) or second (Free), times the speed of the kind
//@slider min=0.2 max=4.0 value=1.0
uniform float drop_size;
//@slider min=0.0 max=4.0 value=1.0
uniform float streak;         // the length of a drop's streak
//@slider min=0.0 max=2.0 value=1.0
uniform float splash;         // how much a drop splashes where it hits (Snow: how long a flake stays)
//@int min=1 max=3 value=3
uniform int layers;           // depth layers: the far ones are finer and slower
//@rgb value=(0.7, 0.85, 1.0)
uniform vec3 drop_color;
//@rgb value=(0.9, 0.95, 1.0)
uniform vec3 splash_color;
//@slider min=0.0 max=2.0 value=0.6
uniform float surface_glow;   // the top surfaces the drops land on glisten
//@slider min=0.0 max=2.0 value=0.0
uniform float flash;          // a pulse lights the surfaces up like lightning (Pulse every, Trigger)
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@enum options=(Black, Colour, Transparent, Drops over it) value=0
uniform int obstacle_view;    // what the surfaces show
//@rgb value=(0.12, 0.13, 0.16)
uniform vec3 obstacle_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float show_mask;      // calibration: the mask in red over the picture

// the fall map in pixels of the full picture, at a pixel position
float fall_px(vec2 pos) {
    vec2 hres = vec2(textureSize(H10, 0));
    float scale = iResolution.x / hres.x;
    return rn_fetch(H10, pos / scale) * scale;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    mp_mask_mode_from(N);   // not textureSize(mask) here: this pass has other inputs (#880)
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    vec2 d = rn_dir();
    vec2 e = vec2(-d.y, d.x);
    vec2 C = res * 0.5;
    float xp = dot(fragCoord - C, e);

    // the kinds: speed (screens per beat), streak (px), dot radius (px), splash dots, life of a splash (beats)
    float k_speed = kind == 1 ? 0.12 : (kind == 2 ? 1.1 : (kind == 3 ? 0.25 : 1.6));
    float k_len = kind == 1 ? 0.0 : (kind == 2 ? 28.0 : (kind == 3 ? 40.0 : 70.0));
    float k_rad = kind == 1 ? 2.8 : (kind == 2 ? 1.5 : (kind == 3 ? 3.5 : 1.6));
    float k_life = kind == 1 ? 3.0 * splash : (kind == 2 ? 0.7 : 0.35) * max(splash, 0.01);
    vec3 pl = mp_pulse(T);

    vec3 light = vec3(0.0);
    int nl = clamp(layers, 1, 3);
    for (int L = 0; L < 3; L++) {
        if (L >= nl) break;
        float fl = float(L);
        float depth = 1.0 - fl * 0.3;                      // 1 near, 0.4 far
        float cw = mix(9.0, 22.0, depth) * drop_size;    // column width, px
        float v = k_speed * speed * res.y * mix(0.55, 1.0, depth);   // px per beat
        float rad = k_rad * drop_size * mix(0.6, 1.0, depth);
        float len = k_len * streak * drop_size * depth;
        float cb = floor(xp / cw);
        for (int dc = -1; dc <= 1; dc++) {
            float c = cb + float(dc);
            ivec2 ci = ivec2(int(c) + 4096, L * 7 + 3);
            float xc = (c + 0.5 + (mp_rand2(ci) - 0.5) * 0.6) * cw;
            if (kind == 1) xc += sin(iTime * 0.9 + mp_rand2(ci + ivec2(5, 0)) * 6.28) * cw * 0.35;
            // where this column enters and leaves the picture
            vec2 O = C + e * xc;
            vec2 inv = 1.0 / (d + vec2(1e-6));
            vec2 t1 = (vec2(0.0) - O) * inv;
            vec2 t2 = (res - O) * inv;
            float tin = max(min(t1.x, t2.x), min(t1.y, t2.y));
            float tout = min(max(t1.x, t2.x), max(t1.y, t2.y));
            if (tin > tout) continue;
            float hit = tin + 1.0 + fall_px(O + d * (tin + 1.0));
            float tend = min(hit, tout + len + 2.0);
            float tp = dot(fragCoord - O, d);
            float dx = dot(fragCoord - O, e);
            for (int j = 0; j < 2; j++) {
                ivec3 di = ivec3(ci, j);
                if (mp_rand3(di) > density) continue;
                float period = (tout - tin) + len + v * k_life + 40.0;
                float head = tin - len + mod(iTime * v + mp_rand3(di + ivec3(0, 0, 9)) * period, period);
                float b = depth * (1.0 + 0.6 * mp_rand3(di + ivec3(0, 0, 21)));
                if (head < tend) {
                    // the falling drop: a streak behind its head, a dot at the head
                    float along = head - tp;
                    float body = len > 0.5 ? (along >= 0.0 && along <= len && tp < tend ? 1.0 - along / len : 0.0) : 0.0;
                    float across = 1.0 - smoothstep(rad * 0.5, rad * 0.5 + 1.0, abs(dx));
                    float dotv = 1.0 - smoothstep(rad * 0.6, rad + 1.0, length(vec2(dx, along)));
                    float g = max(body * across * 0.8, dotv);
                    light += (kind == 2 ? vec3(1.0, 0.55, 0.15) : drop_color) * g * b;
                } else if (hit < tout + 1.0) {
                    // after the hit: a splash (Rain, Sparks, Light drops) or a flake that stays (Snow)
                    float age = (head - hit) / max(v, 1e-3);
                    if (age > k_life) continue;
                    float fade = 1.0 - age / max(k_life, 1e-3);
                    vec2 hp = vec2(0.0, hit - tp);   // the hit seen from this pixel: (across, along)
                    if (kind == 1) {
                        float dd = length(vec2(dx, hp.y - rad * 0.8));
                        light += splash_color * (1.0 - smoothstep(rad * 0.6, rad + 1.0, dd)) * b * min(fade * 3.0, 1.0);
                        continue;
                    }
                    for (int s = 0; s < 4; s++) {
                        ivec3 si = di + ivec3(0, s * 3 + 1, 40);
                        float ang = (mp_rand3(si) - 0.5) * 2.2;
                        float spd = (kind == 2 ? 220.0 : 120.0) * splash * (0.4 + mp_rand3(si + ivec3(0, 0, 3)));
                        vec2 vel = vec2(sin(ang), -cos(ang)) * spd;           // up, against the fall
                        float grav = kind == 2 ? 700.0 : 500.0;
                        vec2 pos = vel * age + vec2(0.0, 0.5 * grav * age * age);
                        vec2 rel = vec2(dx - pos.x, -hp.y - pos.y);
                        float sd = length(rel);
                        float sr = rad * (kind == 2 ? 0.9 : 0.6);
                        light += (kind == 2 ? vec3(1.0, 0.7, 0.3) : splash_color) * (1.0 - smoothstep(sr * 0.5, sr + 1.0, sd)) * fade * b;
                    }
                }
            }
        }
    }
    if (kind == 3) light *= 1.6;

    // the surfaces: the mask at full size, the top surfaces where drops land glisten
    float solid = mask_blur < 0.25 ? mp_mask(uv) : mp_bilinear_uv(M, uv).r;
    float above = fall_px(fragCoord - d * 6.0);
    float top = solid * (1.0 - smoothstep(1.0, 3.0, abs(6.0 - above - 1.5)));
    vec3 rgb = background;
    if (obstacle_view == 1) rgb = mix(rgb, obstacle_color, solid);
    rgb += light * brightness;
    rgb += splash_color * top * surface_glow * 0.6;
    rgb += vec3(0.75, 0.8, 1.0) * pl.x * flash * (solid * 0.9 + 0.1);
    float alpha = 1.0;
    if (obstacle_view == 0) rgb = mix(rgb, vec3(0.0) + vec3(0.75, 0.8, 1.0) * pl.x * flash * 0.9 + splash_color * top * surface_glow * 0.6, solid);
    else if (obstacle_view == 2) alpha = 1.0 - solid * (1.0 - clamp(top * surface_glow + pl.x * flash, 0.0, 1.0));
    if (show_mask > 0.0) {
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), show_mask * 0.45 * mp_bilinear_uv(M, uv).r);
        alpha = max(alpha, show_mask);
    }
    fragColor = vec4(rgb, alpha);
}
