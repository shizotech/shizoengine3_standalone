//@settings dtype=float32 format=rgba
// --- Monolith: a glossy black cube (pyramid, prism, octahedron, slab) that glows like crazy, alone in the dark ---
// Black lacquer with a clear coat, brushed metal on the bevels, neon lines on the edges and veins of light on the
// faces. The object pours its light into the space around it: a hot halo that hugs the shape, a wide glow that fills
// the picture (lit smoke with Haze) and light rays that shoot out of it, all pumped by the kicks. Environment Void
// (the default) shows nothing else; City, Panels and Studio put the old neon world around it (with Floor reflection
// a wet floor). The camera orbits; the music (the sound of the port Audio, else the beat) pushes a spring that pulses
// the object. Glitch: slices, RGB split, a torn picture or the object shattered into blocks, all the time, on a beat,
// on the kicks of the sound or while Glitch hold is on (map it to a MIDI pad).
// Passes: S the state of the music (4 pixels), A the object and its halo in linear light, B and C the bloom (a
// quarter and a sixteenth of the size), R the light rays (a quarter, 24 / 40 samples), this one the glitch, glow,
// tone mapping and film look. Cost (1920x1080, per pixel of A): Quality 1 up to 72 march steps; 2 up to 110 + a
// reflection march of the object itself (48) and a soft shadow (24); 3 is 2 with 4 samples a pixel (4 times the
// cost). A floor (City, Panels, Studio) adds a reflection march of 32 / 56.
#include lib/common.glsl

// The passes: A the object in linear light (alpha: how much of the pixel it covers), B and C its glow, S the state
uniform sampler2D A;
uniform sampler2D B;
uniform sampler2D C;
uniform sampler2D R;
uniform sampler2D S;

//@slider min=-4.0 max=4.0 value=0.0
uniform float exposure;             // stops: +1 doubles the light
//@enum options=(AgX, AgX punchy, ACES, Neutral) value=1
uniform int tone_mapping;           // how bright light is squeezed into the picture: AgX like film, ACES more contrast
//@slider min=0.0 max=2.0 value=0.6
uniform float bloom;                // glow around the bright parts
//@slider min=0.0 max=1.0 value=0.5
uniform float bloom_size;           // 0 a tight glow, 1 a wide haze
//@slider min=0.0 max=1.0 value=0.35
uniform float vignetting;           // darker corners
//@slider min=0.0 max=1.0 value=0.12
uniform float grain;                // film grain
//@slider min=0.0 max=1.0 value=1.0
uniform float edge_smoothing;       // softens stair steps on edges (cheap antialiasing; Quality 3 does it properly)

vec3 sampleA(vec2 uv) {
    return min(passBilinear(A, uv).rgb, vec3(64.0));
}
float lumaLog(vec3 c) {
    return log2(1.0 + dot(c, vec3(0.2126, 0.7152, 0.0722)));
}
// The picture at uv with the stair steps of edges blended along the edge
vec4 sampleSmooth(vec2 uv, vec2 px) {
    vec4 c = passBilinear(A, uv);
    c.rgb = min(c.rgb, vec3(64.0));
    if (edge_smoothing <= 0.0)
        return c;
    float lN = lumaLog(sampleA(uv + vec2(0.0, px.y)));
    float lS = lumaLog(sampleA(uv - vec2(0.0, px.y)));
    float lE = lumaLog(sampleA(uv + vec2(px.x, 0.0)));
    float lW = lumaLog(sampleA(uv - vec2(px.x, 0.0)));
    vec2 n = vec2(lN - lS, lW - lE);
    float e = length(n);
    if (e < 0.05)
        return c;
    vec2 t = n / e * px * 0.85;
    vec4 a = passBilinear(A, uv + t);
    vec4 b = passBilinear(A, uv - t);
    vec4 sm = (c + min(a, vec4(64.0)) + min(b, vec4(64.0))) / 3.0;
    return mix(c, sm, edge_smoothing * clamp(e * 3.0, 0.0, 1.0));
}

// A small pass blown up smoothly: a cubic B-spline from four bilinear taps (no squares or diamonds in the glow)
vec3 bsplineSample(sampler2D s, vec2 uv) {
    vec2 size = vec2(textureSize(s, 0));
    vec2 p = uv * size - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 f2 = f * f, f3 = f2 * f;
    vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
    vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
    vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
    vec2 w3 = f3 / 6.0;
    vec2 g0 = w0 + w1, g1 = w2 + w3;
    vec2 h0 = (i - 0.5 + w1 / g0) / size;
    vec2 h1 = (i + 1.5 + w3 / g1) / size;
    return g0.y * (g0.x * passBilinear(s, vec2(h0.x, h0.y)).rgb + g1.x * passBilinear(s, vec2(h1.x, h0.y)).rgb)
         + g1.y * (g0.x * passBilinear(s, vec2(h0.x, h1.y)).rgb + g1.x * passBilinear(s, vec2(h1.x, h1.y)).rgb);
}

vec3 toneMap(vec3 c) {
    if (tone_mapping == 1)
        return tonemapAgXPunchy(c);
    if (tone_mapping == 2)
        return tonemapACES(c * 1.6);
    if (tone_mapping == 3)
        return tonemapNeutral(c);
    return tonemapAgX(c);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    vec2 px = 1.0 / res;
    vec4 bt = texelFetch(S, ivec2(ST_BEAT, 0), 0);
    float g = glitchAmount(bt);
    // the glitch pattern changes 4 times a beat and with every new glitch
    float seed = fract(bt.z + floor(iTime * 4.0) * 0.1234567);
    int kind = glitchKindFor(bt.z + floor(iTime * 2.0) * 0.37);

    vec2 st = uv;
    vec2 split = vec2(0.0);
    float scan = 1.0;
    vec3 flash = vec3(0.0);
    if (g > 0.001) {
        float sd = floor(seed * 997.0);
        if (kind == 1 || kind == 4) {
            // slices: bands of the picture pushed sideways
            float rows = 6.0 + floor(hash12(vec2(sd, 3.0)) * 26.0);
            float band = floor(uv.y * rows + hash12(vec2(sd, 5.0)));
            float on = step(hash12(vec2(band, sd)), g * (kind == 4 ? 0.35 : 0.75));
            st.x += on * (hash12(vec2(band, sd + 17.0)) - 0.5) * 0.25 * g;
            split = vec2(on * 0.006 * g, 0.0);
        }
        if (kind == 2) {
            // RGB split: red and blue pulled apart, a little different per band
            float band = floor(uv.y * 12.0);
            float j = hash12(vec2(band, sd + 9.0));
            split = vec2(0.004 + 0.016 * j, 0.002 * (j - 0.5)) * g * 1.5;
        }
        if (kind == 3) {
            // tear: the lines wobble, a band of them jumps, scan lines and blocks of digital noise
            float tearY = fract(hash12(vec2(sd, 1.0)) + iTime * 0.37);
            float tearH = 0.03 + 0.12 * hash12(vec2(sd, 2.0));
            float inTear = step(abs(uv.y - tearY), tearH * 0.5);
            st.x += sin(uv.y * 180.0 + iTime * 30.0) * 0.0025 * g;
            st.x += inTear * (hash12(vec2(sd, 4.0)) - 0.5) * 0.3 * g;
            st.y += inTear * 0.01 * g;
            scan = 1.0 - 0.35 * g * (0.5 + 0.5 * sin(fragCoord.y * 3.14159));
            vec2 blk = floor(fragCoord / 24.0);
            float bn = hash12(blk + sd * 13.0);
            if (bn < 0.06 * g) {
                st = (blk * 24.0 + vec2(hash12(blk + 1.0) * 400.0 - 200.0, 0.0)) * px + mod(fragCoord, 24.0) * px;
                flash = vec3(0.4, 0.9, 1.0) * 0.15 * g;
            }
            flash += inTear * vec3(0.8, 0.2, 1.0) * 0.06 * g;
            split = vec2(0.003 * g, 0.0);
        }
    }

    vec4 c = sampleSmooth(st, px);
    if (dot(split, split) > 0.0) {
        vec4 r = passBilinear(A, st + split);
        vec4 b = passBilinear(A, st - split);
        c.r = min(r.r, 64.0);
        c.b = min(b.b, 64.0);
        c.a = max(c.a, max(r.a, b.a));
    }

    // the glow
    // (less of it over the object, so its faces stay dark next to the bright halo)
    vec3 glow = mix(bsplineSample(B, st), bsplineSample(C, st) * 1.5, bloom_size) * bloom * (1.0 - 0.5 * clamp(c.a, 0.0, 1.0));
    // the light rays, behind the object (its faces stay dark)
    glow += bsplineSample(R, st) * rays * (1.0 - 0.97 * clamp(c.a, 0.0, 1.0));
    vec3 col = c.rgb + glow + flash;
    col *= scan;

    // the background colour behind the object
    if (background_mode == 1)
        col += srgbToLinear(background_color) * (1.0 - clamp(c.a, 0.0, 1.0));

    vec2 q = uv - 0.5;
    float aspect = iResolution.x / iResolution.y;
    col *= 1.0 - vignetting * smoothstep(0.2, 0.95, length(q * vec2(aspect, 1.0)) / max(aspect, 1.0) * 1.35);
    col *= exp2(exposure);
    if (grain > 0.0)
        col = filmGrain(col, grain * 0.08, hash13(vec3(fragCoord, float(iFrame % 1024))) * 2.0 - 1.0);
    col = max(col, vec3(0.0));

    vec3 outc = linearToSrgb(clamp(toneMap(col), 0.0, 1.0)) + ditherTPDF(fragCoord, iFrame);
    float alpha = 1.0;
    if (background_mode == 2) {
        // premultiplied: black where there is nothing; the glow, the halo and the rays count as cover too
        alpha = clamp(max(c.a, max(max(outc.r, outc.g), outc.b)), 0.0, 1.0);
    }
    fragColor = vec4(clamp(outc, 0.0, 1.0), alpha);
}
