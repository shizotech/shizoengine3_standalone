// ==== Force2Colors ==========================================================
// Zwingt JEDEN beliebigen Input auf exakt ZWEI Farben.
//
// Pipeline:
//   1. Input -> eine einzige 0..1 Maske (waehlbare Quelle: Luma, Sattigung,
//      Hue, Farbabstand, einzelner Kanal, ...)
//   2. Maske aufbereiten (Auto-Level, Kontrast, Gamma, Invert)
//   3. Schwelle (threshold) + optionale Modulation (Verlauf, Radial, Beat)
//   4. HARDNESS: 1.0 = harte Kante -> mathematisch exakt zwei Farben,
//      0.0 = weicher Verlauf zwischen den beiden Farben
//   5. Dither: erzeugt Halbton-Verlaeufe OHNE eine dritte Farbe zu benutzen
//
// Bei hardness=1, edge_aa=0, mix_original=0 enthaelt das Bild garantiert nur
// color_dark und color_light - sonst nichts.

#include lib/mask.glsl

//@settings dtype=float32 format=rgba

uniform sampler2D input;

// ---- 1. Woraus wird getrennt ----------------------------------------------

//@enum options=(Luma, Average, MaxChannel, MinChannel, Saturation, Hue, ColorDistance, Red, Green, Blue, Alpha) value=0
uniform int source_mode;

//@rgb value=(1.0,0.0,0.0)
uniform vec3 ref_color;          // nur fuer "Color Distance"

//@button
uniform bool invert;

// ---- 2. Maske aufbereiten --------------------------------------------------

//@slider min=0.0 max=1.0 value=0.0
uniform float auto_level;        // spreizt gemessenes min/max auf 0..1

//@slider min=0.0 max=1.0 value=0.0
uniform float auto_threshold;    // zieht die Schwelle auf die Bildmitte-Helligkeit

//@float min=0.0 max=8.0 value=1.0
uniform float contrast;          // um 0.5 herum

//@float min=0.1 max=4.0 value=1.0
uniform float gamma;

// ---- 3. Schwelle -----------------------------------------------------------

//@slider min=0.0 max=1.0 value=0.5
uniform float threshold;

//@slider min=0.0 max=1.0 value=1.0
uniform float hardness;          // 1 = exakt zwei Farben, 0 = weicher Verlauf

//@slider min=0.0 max=2.0 value=0.0
uniform float edge_aa;           // >0 glaettet die Kante (erzeugt Zwischentoene!)

//@slider min=-0.5 max=0.5 value=0.0
uniform float tilt_amount;       // linearer Schwellen-Verlauf ueber das Bild

//@slider min=0.0 max=1.0 value=0.0
uniform float tilt_angle;        // 0..1 = 0..360 Grad

//@slider min=-0.5 max=0.5 value=0.0
uniform float radial_amount;     // Schwelle von Mitte nach aussen

// ---- 4. Dither -------------------------------------------------------------

//@enum options=(Off, Bayer8, Bayer4, Interleaved, Noise) value=0
uniform int dither_mode;

//@slider min=0.0 max=1.0 value=0.0
uniform float dither_amount;     // 1.0 = voller Halbton-Verlauf

//@float min=1.0 max=32.0 value=1.0
uniform float dither_scale;      // Punktgroesse in Pixeln

//@button
uniform bool dither_animate;     // Muster pro Beat neu wuerfeln

// ---- 5. Die zwei Farben ----------------------------------------------------

//@rgb value=(0.04,0.02,0.12)
uniform vec3 color_dark;         // unterhalb der Schwelle

//@rgb value=(1.0,0.24,0.62)
uniform vec3 color_light;        // oberhalb der Schwelle

//@button
uniform bool swap_colors;

//@float min=0.0 max=16.0 value=0.0
uniform float swap_beats;        // >0: tauscht die Farben alle N Beats

// ---- 6. Beat / Ausgabe -----------------------------------------------------

//@slider min=-0.5 max=0.5 value=0.0
uniform float beat_amount;       // Schwelle pulsiert im Takt

//@float min=0.25 max=16.0 value=4.0
uniform float beat_length;       // Laenge eines Pulses in Beats

//@slider min=0.0 max=1.0 value=0.0
uniform float mix_original;      // blendet das Original zurueck

//@button
uniform bool keep_alpha;

//@button
uniform bool preview_mask;       // zeigt die rohe Maske zum Einstellen

const float C2_TAU = 6.28318530718;
const int   C2_SCAN = 7;         // 7x7 Raster fuer Auto-Level / Auto-Threshold

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv  = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);

    // ---------- 1. Maske ----------
    float m = clamp(c2_source(src.rgb, src.a, source_mode, ref_color), 0.0, 1.0);

    // ---------- 2. Auto-Level / Auto-Threshold ----------
    // Grober Scan des Bildes. Der Zweig haengt nur an Uniforms, ist also fuer
    // alle Pixel gleich -> kostet nichts wenn beide Regler auf 0 stehen.
    float scan_min = 0.0;
    float scan_max = 1.0;
    float scan_mean = 0.5;
    if (auto_level > 0.001 || auto_threshold > 0.001) {
        float lo = 1.0;
        float hi = 0.0;
        float sum = 0.0;
        for (int y = 0; y < C2_SCAN; y++) {
            for (int x = 0; x < C2_SCAN; x++) {
                vec2 suv = (vec2(float(x), float(y)) + 0.5) / float(C2_SCAN);
                vec4 s = texture(input, suv);
                float sm = clamp(c2_source(s.rgb, s.a, source_mode, ref_color), 0.0, 1.0);
                lo = min(lo, sm);
                hi = max(hi, sm);
                sum += sm;
            }
        }
        scan_min = lo;
        scan_max = hi;
        scan_mean = sum / float(C2_SCAN * C2_SCAN);
    }

    float span = max(scan_max - scan_min, 0.001);
    float m_norm = clamp((m - scan_min) / span, 0.0, 1.0);
    float mean_norm = clamp((scan_mean - scan_min) / span, 0.0, 1.0);
    m = mix(m, m_norm, auto_level);
    float mean = mix(scan_mean, mean_norm, auto_level);

    if (invert) m = 1.0 - m;
    m = clamp((m - 0.5) * contrast + 0.5, 0.0, 1.0);
    m = pow(m, max(gamma, 0.0001));

    // ---------- 3. Schwelle + Modulation ----------
    // auto_threshold legt die Schwelle auf die mittlere Helligkeit, der
    // threshold-Regler wirkt dann als Offset dazu.
    float auto_thr = mean + (threshold - 0.5);
    if (invert) auto_thr = (1.0 - mean) + (threshold - 0.5);
    float thr = mix(threshold, auto_thr, auto_threshold);

    vec2 centered = uv - 0.5;
    centered.x *= iResolution.z;                       // Seitenverhaeltnis
    float ang = tilt_angle * C2_TAU;
    thr += dot(centered, vec2(cos(ang), sin(ang))) * tilt_amount * 2.0;
    thr += (length(centered) * 2.0 - 0.5) * radial_amount * 2.0;
    thr += sin(iTime * C2_TAU / max(beat_length, 0.0001)) * beat_amount;
    thr = clamp(thr, -0.001, 1.001);

    // ---------- 4. Dither ----------
    // Wird auf die Maske addiert, NICHT auf die Farbe: das Ergebnis bleibt
    // dadurch strikt zweifarbig, sieht aber wie ein Verlauf aus.
    if (dither_mode > 0 && dither_amount > 0.0) {
        vec2 dpx = fragCoord / max(dither_scale, 1.0);
        float dt = dither_animate ? floor(iTime) * 37.0 : 0.0;
        m += c2_dither(dither_mode, dpx, dt) * dither_amount;
    }

    // ---------- 5. Quantisierung auf zwei Zustaende ----------
    float w = mix(0.5, 0.0, clamp(hardness, 0.0, 1.0));
    w += edge_aa * fwidth(m) * 0.5;

    float t;
    if (w <= 0.0) {
        t = step(thr, m);                              // exakt 0 oder 1
    } else {
        t = smoothstep(thr - w, thr + w, m);
    }

    if (preview_mask) {
        fragColor = vec4(vec3(t), 1.0);
        return;
    }

    // ---------- 6. Farben ----------
    bool flip = swap_colors;
    if (swap_beats > 0.0) {
        flip = flip != (mod(floor(iTime / swap_beats), 2.0) >= 1.0);
    }
    vec3 lo_col = flip ? color_light : color_dark;
    vec3 hi_col = flip ? color_dark : color_light;

    vec3 col = mix(lo_col, hi_col, t);
    col = mix(col, src.rgb, mix_original);

    float a = keep_alpha ? src.a : 1.0;
    fragColor = vec4(clamp(col, 0.0, 1.0), a);
}
