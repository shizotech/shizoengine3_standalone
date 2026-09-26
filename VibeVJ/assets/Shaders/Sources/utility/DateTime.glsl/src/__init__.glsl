// DateTime Source
// Renders the current clock time and/or date as a 7-segment style display.
// Fully configurable: display format (HH:MM, HH:MM:SS, DD.MM.YYYY, MM/DD/YYYY,
// YYYY-MM-DD or two-line time+date combinations), text size, position offset,
// stroke width, corner rounding, glyph pitch, colours, blinking colon and the
// time source (system clock or beat counter).
//
// Shadertoy-style mainImage. iResolution / iTime / iDate / iFrame / iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Display format ----
//@enum options=(HH:MM, HH:MM:SS, DD.MM.YYYY, MM/DD/YYYY, YYYY-MM-DD, HH:MM + Date, HH:MM:SS + Date, Date + HH:MM)
uniform int format_mode;

// ---- Size / position ----
//@slider min=0.02 max=1.0 value=0.28
uniform float text_height;         // glyph height as a fraction of the screen height

//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 position;             // centre of the text block (uv space)

//@vec2 min=(-1,-1) max=(1,1) value=(0,0)
uniform vec2 offset;               // fine position offset (uv units)

//@button
uniform bool flip_y;               // flip the glyphs vertically (for flipped uv origin)

// ---- Time source ----
//@enum options=(System Time, Beat Counter)
uniform int clock_source;

//@float min=0.1 max=4.0 value=0.5
uniform float seconds_per_beat;    // used by the beat counter (iTime is in beats)

//@float min=-12 max=14 value=0
uniform float hours_offset;        // timezone offset in hours

// ---- Glyph shape ----
//@slider min=0.04 max=0.30 value=0.12
uniform float stroke_width;        // segment thickness (relative to glyph height)

//@slider min=0.5 max=1.0 value=0.66
uniform float glyph_width;         // glyph width (relative to glyph height)

//@slider min=0.55 max=1.2 value=0.72
uniform float glyph_pitch;         // horizontal advance (relative to glyph height)

//@slider min=0.0 max=0.5 value=0.12
uniform float corner_radius;       // 0 = hard corners, higher = rounded segments

// ---- Colours ----
//@rgb value=(1.0,1.0,1.0)
uniform vec3 text_color;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 background_color;

//@slider min=0.0 max=1.0 value=1.0
uniform float text_opacity;

//@slider min=0.0 max=1.0 value=0.0
uniform float background_opacity;  // 0 = transparent background (overlay), 1 = opaque

// ---- Behaviour ----
//@button
uniform bool blink_colon;          // blink the ':' separators on the beat

//@slider min=0.25 max=4.0 value=1.0
uniform float blink_rate;          // blink cycles per beat

// =====================================================================
// Helpers
// =====================================================================

float sdRoundBar(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

int getDigit(int value, int place)
{
    int d = int(floor(float(value) / pow(10.0, float(place))));
    return int(mod(float(d), 10.0));
}

// 7-segment mask. Bits: 0 top, 1 top-left, 2 top-right, 3 middle,
// 4 bottom-left, 5 bottom-right, 6 bottom.
int segMask(int d)
{
    if (d == 0) return 119;
    if (d == 1) return 36;
    if (d == 2) return 109;
    if (d == 3) return 117;
    if (d == 4) return 46;
    if (d == 5) return 107;
    if (d == 6) return 123;
    if (d == 7) return 37;
    if (d == 8) return 127;
    return 47; // 9
}

bool segOn(int mask, int bit)
{
    float v = floor(float(mask) / pow(2.0, float(bit)));
    return mod(v, 2.0) > 0.5;
}

float digitSDF(vec2 p, int d, float lh)
{
    int m = segMask(d);
    float hh = lh * 0.5;
    float hw = glyph_width * lh * 0.5;
    float t = stroke_width * lh;
    float r = min(corner_radius * t, t * 0.49);

    float dmin = 1e9;

    // Horizontal segments
    if (segOn(m, 0)) dmin = min(dmin, sdRoundBar(p - vec2(0.0,  hh), vec2(hw, t * 0.5), r));
    if (segOn(m, 3)) dmin = min(dmin, sdRoundBar(p,               vec2(hw, t * 0.5), r));
    if (segOn(m, 6)) dmin = min(dmin, sdRoundBar(p - vec2(0.0, -hh), vec2(hw, t * 0.5), r));

    // Vertical segments
    float vc = hh * 0.5;
    if (segOn(m, 1)) dmin = min(dmin, sdRoundBar(p - vec2(-hw,  vc), vec2(t * 0.5, hh * 0.5), r));
    if (segOn(m, 2)) dmin = min(dmin, sdRoundBar(p - vec2( hw,  vc), vec2(t * 0.5, hh * 0.5), r));
    if (segOn(m, 4)) dmin = min(dmin, sdRoundBar(p - vec2(-hw, -vc), vec2(t * 0.5, hh * 0.5), r));
    if (segOn(m, 5)) dmin = min(dmin, sdRoundBar(p - vec2( hw, -vc), vec2(t * 0.5, hh * 0.5), r));

    return dmin;
}

// kind: 0 = dot, 1 = colon, 2 = dash, 3 = slash
float sepSDF(vec2 p, float x_center, int kind, float lh)
{
    float t = stroke_width * lh;
    float hw = glyph_width * lh * 0.5;

    if (kind == 0)
        return length(p - vec2(x_center, 0.0)) - t * 0.6;

    if (kind == 1) {
        float rr = t * 0.6;
        float a = length(p - vec2(x_center,  lh * 0.24)) - rr;
        float b = length(p - vec2(x_center, -lh * 0.24)) - rr;
        return min(a, b);
    }

    if (kind == 2) {
        float r = min(corner_radius * t, t * 0.49);
        return sdRoundBar(p - vec2(x_center, 0.0), vec2(hw * 0.8, t * 0.5), r);
    }

    // slash: capsule from bottom-left to top-right
    vec2 q = p - vec2(x_center, 0.0);
    vec2 a = vec2(-hw * 0.7, -lh * 0.42);
    vec2 b = vec2( hw * 0.7,  lh * 0.42);
    vec2 pa = q - a;
    vec2 ba = b - a;
    float hgt = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * hgt) - t * 0.5;
}

float digitsField(vec2 p, float x_start, int count, int value, float lh)
{
    float pitch = glyph_pitch * lh;
    float dmin = 1e9;
    for (int k = 0; k < 4; k++) {
        if (k >= count) break;
        int place = count - 1 - k;
        vec2 gc = p - vec2(x_start + (float(k) + 0.5) * pitch, 0.0);
        dmin = min(dmin, digitSDF(gc, getDigit(value, place), lh));
    }
    return dmin;
}

// Draw one text line, centered horizontally on x = 0.
// kind: 0 HH:MM, 1 HH:MM:SS, 2 DD.MM.YYYY, 3 MM/DD/YYYY, 4 YYYY-MM-DD
float lineSDF(vec2 p, int kind, float lh, int hours, int mins, int secs, int dayv, int monthv, int yearv, float colon_vis)
{
    float pitch = glyph_pitch * lh;

    float cells = 10.0;
    if (kind == 0) cells = 5.0;
    else if (kind == 1) cells = 7.0;

    float xs = -0.5 * cells * pitch;
    float off = 1e9;

    if (kind == 0) {
        float d = digitsField(p, xs, 2, hours, lh);
        d = min(d, sepSDF(p, xs + 2.5 * pitch, 1, lh) + off * (1.0 - colon_vis));
        d = min(d, digitsField(p, xs + 3.0 * pitch, 2, mins, lh));
        return d;
    }

    if (kind == 1) {
        float d = digitsField(p, xs, 2, hours, lh);
        d = min(d, sepSDF(p, xs + 2.5 * pitch, 1, lh) + off * (1.0 - colon_vis));
        d = min(d, digitsField(p, xs + 3.0 * pitch, 2, mins, lh));
        d = min(d, sepSDF(p, xs + 5.5 * pitch, 1, lh) + off * (1.0 - colon_vis));
        d = min(d, digitsField(p, xs + 6.0 * pitch, 2, secs, lh));
        return d;
    }

    if (kind == 2) {
        float d = digitsField(p, xs, 2, dayv, lh);
        d = min(d, sepSDF(p, xs + 2.5 * pitch, 0, lh));
        d = min(d, digitsField(p, xs + 3.0 * pitch, 2, monthv, lh));
        d = min(d, sepSDF(p, xs + 5.5 * pitch, 0, lh));
        d = min(d, digitsField(p, xs + 6.0 * pitch, 4, yearv, lh));
        return d;
    }

    if (kind == 3) {
        float d = digitsField(p, xs, 2, monthv, lh);
        d = min(d, sepSDF(p, xs + 2.5 * pitch, 3, lh));
        d = min(d, digitsField(p, xs + 3.0 * pitch, 2, dayv, lh));
        d = min(d, sepSDF(p, xs + 5.5 * pitch, 3, lh));
        d = min(d, digitsField(p, xs + 6.0 * pitch, 4, yearv, lh));
        return d;
    }

    // kind == 4 : YYYY-MM-DD
    float d4 = digitsField(p, xs, 4, yearv, lh);
    d4 = min(d4, sepSDF(p, xs + 4.5 * pitch, 2, lh));
    d4 = min(d4, digitsField(p, xs + 5.0 * pitch, 2, monthv, lh));
    d4 = min(d4, sepSDF(p, xs + 7.5 * pitch, 2, lh));
    d4 = min(d4, digitsField(p, xs + 8.0 * pitch, 2, dayv, lh));
    return d4;
}

float coverage(float d, float aa)
{
    return 1.0 - smoothstep(-aa, aa, d);
}

// =====================================================================
// Main
// =====================================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    // ---- seconds of the displayed day ----
    float secs = 0.0;
    if (clock_source == 0)
        secs = iDate.w;
    else
        secs = iTime * seconds_per_beat;
    secs += hours_offset * 3600.0;
    secs = mod(secs, 86400.0);
    if (secs < 0.0)
        secs += 86400.0;

    int hours = int(mod(floor(secs / 3600.0), 24.0));
    int mins  = int(mod(floor(secs / 60.0), 60.0));
    int secv  = int(mod(floor(secs), 60.0));

    // ---- date (from the engine-provided iDate, with safe fallbacks) ----
    float month = max(iDate.y, 0.0);
    if (month < 1.0)
        month += 1.0;              // handle 0-based months
    month = clamp(month, 1.0, 12.0);

    float day = clamp(max(iDate.z, 1.0), 1.0, 31.0);

    float year = iDate.x;
    if (year < 100.0)
        year = 2000.0;

    int dayv = int(day);
    int monthv = int(month);
    int yearv = int(year);

    // ---- glyph space: height-normalized, centered on 'position' ----
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 q = uv - position - offset;
    q.x *= aspect;
    if (flip_y)
        q.y = -q.y;

    float aa = 1.5 / max(iResolution.y, 1.0);
    float colon_vis = 1.0;
    if (blink_colon)
        colon_vis = step(0.5, fract(iTime * blink_rate));

    // ---- two-line formats ----
    int two_line = 0;
    if (format_mode == 5 || format_mode == 6 || format_mode == 7)
        two_line = 1;

    float lh = text_height;
    if (two_line == 1)
        lh = text_height * 0.45;

    float mask = 0.0;

    if (two_line == 0) {
        mask = coverage(lineSDF(q, format_mode, lh, hours, mins, secv, dayv, monthv, yearv, colon_vis), aa);
    }
    else {
        int k1 = 0;
        int k2 = 2;
        if (format_mode == 5) { k1 = 0; k2 = 2; }
        if (format_mode == 6) { k1 = 1; k2 = 2; }
        if (format_mode == 7) { k1 = 2; k2 = 0; }

        float line_gap = lh * 1.35;
        vec2 p1 = q - vec2(0.0,  0.5 * line_gap);
        vec2 p2 = q - vec2(0.0, -0.5 * line_gap);

        float m1 = coverage(lineSDF(p1, k1, lh, hours, mins, secv, dayv, monthv, yearv, colon_vis), aa);
        float m2 = coverage(lineSDF(p2, k2, lh, hours, mins, secv, dayv, monthv, yearv, colon_vis), aa);
        mask = max(m1, m2);
    }

    mask = clamp(mask * text_opacity, 0.0, 1.0);

    vec3 col = mix(background_color, text_color, mask);
    float alpha = clamp(max(mask, background_opacity), 0.0, 1.0);

    fragColor = vec4(col, alpha);
}
