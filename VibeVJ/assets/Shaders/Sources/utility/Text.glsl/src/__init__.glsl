// Text Source
// Renders a configurable text string as a crisp built-in 5x7 bitmap font.
// No input required (self-contained source). Type the text directly into the
// editable textbox (the engine transports it into per-character uniforms so it
// stays mappable/linkable), and configure the display via format (alignment +
// style), size and the position offset.
//
// Shadertoy-style mainImage. iResolution / iTime / iDate / iFrame / iMouse are
// engine-injected - do NOT redeclare them.
//
// Default text: "HTTP". Lowercase a-z (97..122) is auto-mapped to uppercase.
// Space = 32. Maximum 16 characters.
//
// Size is set independently per axis: 'text_height' (fraction of screen height)
// and 'text_width' (fraction of screen width) control glyph height and glyph
// advance width separately.
//
// Scrolling (scroll_speed) wraps: once the last character has left the image,
// the same line starts again from the front, with no gap and no jump.

//@settings dtype=float32 format=rgba

// ---- Text content ----
// Edit the display text directly in the textbox below (type any text).
// The engine transports the string into the per-character uniforms
// (char1..char16) plus char_count, so it stays mappable/linkable.
// Lowercase a-z is auto-uppercased in the shader. Space = 32. Max 16 chars.
//@text prefix=char slots=16 count=char_count value="HTTP" displayname="Text"
uniform int text;

// Per-character ASCII codes (filled automatically from the textbox above).
uniform int char1;
uniform int char2;
uniform int char3;
uniform int char4;
uniform int char5;
uniform int char6;
uniform int char7;
uniform int char8;
uniform int char9;
uniform int char10;
uniform int char11;
uniform int char12;
uniform int char13;
uniform int char14;
uniform int char15;
uniform int char16;

// Number of active character slots (set automatically from the textbox length).
uniform int char_count;

// ---- Size / position ----
//@slider min=0.02 max=1.0 value=0.22
uniform float text_height;         // glyph height as a fraction of the screen height

//@slider min=0.02 max=1.0 value=0.125
uniform float text_width;          // glyph advance width as a fraction of the screen width
                                   // (was previously derived implicitly from
                                   // text_height / aspect; 0.125 with text_height
                                   // 0.22 reproduces that look on a 16:9 area)

//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 position;             // anchor of the text block (uv space)

//@vec2 min=(-1,-1) max=(1,1) value=(0,0)
uniform vec2 offset;               // fine position offset (uv units)

//@slider min=0.1 max=1.0 value=0.35
uniform float letter_spacing;      // extra gap between glyphs (in glyph-width units)

//@button
uniform bool flip_y;               // flip the glyphs vertically (for flipped uv origin)

// ---- Format ----
//@enum options=(Left, Center, Right)
uniform int alignment;             // horizontal alignment relative to 'position'

//@enum options=(Solid, Glow, Outline)
uniform int style;                 // rendering style

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
//@slider min=0.0 max=1.0 value=0.0
uniform float glow_strength;       // halo size for Glow style

//@float min=-20 max=20 value=0
uniform float scroll_speed;        // horizontal scroll speed (uv/s * iTime), 0 = static

// =====================================================================
// Built-in 5x7 bitmap font. Each glyph is 5 columns; each column is a 7-bit
// pattern where bit 0 is the TOP row and bit 6 the BOTTOM row.
// =====================================================================

void glyphBits(int code, out int c0, out int c1, out int c2, out int c3, out int c4)
{
    c0 = 0; c1 = 0; c2 = 0; c3 = 0; c4 = 0;

    // Map lowercase a-z to uppercase A-Z.
    if (code >= 97 && code <= 122)
        code -= 32;

    // space
    if (code == 32) { c0=0;  c1=0;  c2=0;  c3=0;  c4=0; return; }
    // !
    if (code == 33) { c0=0;  c1=0;  c2=95; c3=0;  c4=0; return; }
    // "
    if (code == 34) { c0=0;  c1=7;  c2=0;  c3=7;  c4=0; return; }
    // #
    if (code == 35) { c0=20; c1=127;c2=20; c3=127;c4=20; return; }
    // $
    if (code == 36) { c0=36; c1=42; c2=127;c3=42; c4=18; return; }
    // %
    if (code == 37) { c0=35; c1=19; c2=8;  c3=100;c4=98; return; }
    // &
    if (code == 38) { c0=54; c1=73; c2=85; c3=34; c4=80; return; }
    // '
    if (code == 39) { c0=0;  c1=5;  c2=3;  c3=0;  c4=0; return; }
    // (
    if (code == 40) { c0=0;  c1=28; c2=34; c3=65; c4=0; return; }
    // )
    if (code == 41) { c0=0;  c1=65; c2=34; c3=28; c4=0; return; }
    // *
    if (code == 42) { c0=20; c1=8;  c2=62; c3=8;  c4=20; return; }
    // +
    if (code == 43) { c0=8;  c1=8;  c2=62; c3=8;  c4=8; return; }
    // ,
    if (code == 44) { c0=0;  c1=80; c2=48; c3=0;  c4=0; return; }
    // -
    if (code == 45) { c0=8;  c1=8;  c2=8;  c3=8;  c4=8; return; }
    // .
    if (code == 46) { c0=0;  c1=96; c2=96; c3=0;  c4=0; return; }
    // /
    if (code == 47) { c0=32; c1=16; c2=8;  c3=4;  c4=2; return; }
    // 0
    if (code == 48) { c0=62; c1=81; c2=73; c3=69; c4=62; return; }
    // 1
    if (code == 49) { c0=0;  c1=66; c2=127;c3=64; c4=0; return; }
    // 2
    if (code == 50) { c0=66; c1=97; c2=73; c3=73; c4=70; return; }
    // 3
    if (code == 51) { c0=33; c1=65; c2=69; c3=72; c4=49; return; }
    // 4
    if (code == 52) { c0=24; c1=20; c2=18; c3=127;c4=16; return; }
    // 5
    if (code == 53) { c0=39; c1=69; c2=69; c3=69; c4=57; return; }
    // 6
    if (code == 54) { c0=62; c1=73; c2=73; c3=73; c4=50; return; }
    // 7
    if (code == 55) { c0=1;  c1=3;  c2=69; c3=56; c4=16; return; }
    // 8
    if (code == 56) { c0=54; c1=73; c2=73; c3=73; c4=54; return; }
    // 9
    if (code == 57) { c0=6;  c1=73; c2=73; c3=41; c4=30; return; }
    // :
    if (code == 58) { c0=0;  c1=54; c2=54; c3=0;  c4=0; return; }
    // ;
    if (code == 59) { c0=0;  c1=86; c2=54; c3=0;  c4=0; return; }
    // <
    if (code == 60) { c0=8;  c1=16; c2=32; c3=64; c4=0; return; }
    // =
    if (code == 61) { c0=20; c1=20; c2=20; c3=20; c4=20; return; }
    // >
    if (code == 62) { c0=0;  c1=64; c2=32; c3=16; c4=8; return; }
    // ?
    if (code == 63) { c0=2;  c1=1;  c2=81; c3=9;  c4=2; return; }
    // @
    if (code == 64) { c0=62; c1=81; c2=77; c3=93; c4=126; return; }
    // A
    if (code == 65) { c0=124;c1=18; c2=17; c3=18; c4=124; return; }
    // B
    if (code == 66) { c0=127;c1=73; c2=73; c3=73; c4=54; return; }
    // C
    if (code == 67) { c0=62; c1=65; c2=65; c3=65; c4=34; return; }
    // D
    if (code == 68) { c0=127;c1=65; c2=65; c3=34; c4=28; return; }
    // E
    if (code == 69) { c0=127;c1=73; c2=73; c3=73; c4=65; return; }
    // F
    if (code == 70) { c0=127;c1=9;  c2=9;  c3=1;  c4=1; return; }
    // G
    if (code == 71) { c0=62; c1=65; c2=73; c3=73; c4=58; return; }
    // H
    if (code == 72) { c0=127;c1=8;  c2=8;  c3=8;  c4=127; return; }
    // I
    if (code == 73) { c0=0;  c1=65; c2=127;c3=65; c4=0; return; }
    // J
    if (code == 74) { c0=32; c1=64; c2=65; c3=63; c4=1; return; }
    // K
    if (code == 75) { c0=127;c1=8;  c2=20; c3=34; c4=65; return; }
    // L
    if (code == 76) { c0=127;c1=64; c2=64; c3=64; c4=64; return; }
    // M
    if (code == 77) { c0=127;c1=2;  c2=12; c3=2;  c4=127; return; }
    // N
    if (code == 78) { c0=127;c1=4;  c2=8;  c3=16; c4=127; return; }
    // O
    if (code == 79) { c0=62; c1=65; c2=65; c3=65; c4=62; return; }
    // P
    if (code == 80) { c0=127;c1=9;  c2=9;  c3=9;  c4=6; return; }
    // Q
    if (code == 81) { c0=62; c1=65; c2=81; c3=33; c4=126; return; }
    // R
    if (code == 82) { c0=127;c1=9;  c2=25; c3=41; c4=70; return; }
    // S
    if (code == 83) { c0=70; c1=73; c2=73; c3=73; c4=49; return; }
    // T
    if (code == 84) { c0=1;  c1=1;  c2=127;c3=1;  c4=1; return; }
    // U
    if (code == 85) { c0=63; c1=64; c2=64; c3=64; c4=63; return; }
    // V
    if (code == 86) { c0=31; c1=32; c2=64; c3=32; c4=31; return; }
    // W
    if (code == 87) { c0=127;c1=32; c2=24; c3=32; c4=127; return; }
    // X
    if (code == 88) { c0=99; c1=20; c2=8;  c3=20; c4=99; return; }
    // Y
    if (code == 89) { c0=3;  c1=4;  c2=120;c3=4;  c4=3; return; }
    // Z
    if (code == 90) { c0=97; c1=81; c2=73; c3=69; c4=99; return; }
    // [
    if (code == 91) { c0=0;  c1=127;c2=65; c3=65; c4=0; return; }
    // backslash
    if (code == 92) { c0=2;  c1=4;  c2=8;  c3=16; c4=32; return; }
    // ]
    if (code == 93) { c0=0;  c1=65; c2=65; c3=127;c4=0; return; }
    // ^
    if (code == 94) { c0=4;  c1=2;  c2=1;  c3=2;  c4=4; return; }
    // _
    if (code == 95) { c0=64; c1=64; c2=64; c3=64; c4=64; return; }

    // fallback: filled box for unknown codes
    c0 = 127; c1 = 127; c2 = 127; c3 = 127; c4 = 127;
}

// Return the column bit pattern for a glyph at a given (col,row).
int glyphColumnMask(int code, int col)
{
    int c0,c1,c2,c3,c4;
    glyphBits(code, c0, c1, c2, c3, c4);
    if (col == 0) return c0;
    if (col == 1) return c1;
    if (col == 2) return c2;
    if (col == 3) return c3;
    return c4;
}

bool glyphLit(int code, int col, int row)
{
    int mask = glyphColumnMask(code, col);
    float bit = floor(float(mask) / pow(2.0, float(row)));
    return mod(bit, 2.0) > 0.5;
}

int charCodeAt(int idx)
{
    if (idx == 0)  return char1;
    if (idx == 1)  return char2;
    if (idx == 2)  return char3;
    if (idx == 3)  return char4;
    if (idx == 4)  return char5;
    if (idx == 5)  return char6;
    if (idx == 6)  return char7;
    if (idx == 7)  return char8;
    if (idx == 8)  return char9;
    if (idx == 9)  return char10;
    if (idx == 10) return char11;
    if (idx == 11) return char12;
    if (idx == 12) return char13;
    if (idx == 13) return char14;
    if (idx == 14) return char15;
    return char16;
}

// =====================================================================
// Main
// =====================================================================

// Convert a uv position into the glyph-normalized space used for layout.
// X is normalized by text_width (fraction of screen width), Y by text_height
// (fraction of screen height), so width and height can be set independently.
vec2 toGlyphSpace(vec2 uv)
{
    vec2 p;
    p.x = (uv.x - position.x - offset.x) / max(text_width, 1e-4);
    p.y = (uv.y - position.y - offset.y) / max(text_height, 1e-4);
    if (flip_y)
        p.y = -p.y;
    // center the glyph vertically (font rows 0..6)
    p.y += 0.5 * 7.0 / 5.0; // baseline tweak: glyph is 5 units tall after scaling
    return p;
}

// Advance between glyphs in layout units.
float glyphPitch()
{
    return 1.0 + letter_spacing;
}

// Number of active characters.
int activeCharCount()
{
    return int(clamp(float(char_count), 1.0, 16.0));
}

// Left edge of the text line in layout units, for the requested alignment.
float lineStartX()
{
    float total_w = float(activeCharCount()) * glyphPitch();
    if (alignment == 0) return 0.0;              // left
    if (alignment == 1) return -total_w * 0.5;   // center
    return -total_w;                             // right
}

// Wrapped scroll offset in layout units. The offset loops over
// (screen width + line width), so once the LAST character has left the image
// the text starts again from the front instead of scrolling away forever.
float scrollSpanUnits()
{
    float span = 1.0 / max(text_width, 1e-4) + float(activeCharCount()) * glyphPitch();
    if (span <= 0.0) span = 1.0;
    return span;
}

float scrollOffsetUnits()
{
    float span = scrollSpanUnits();
    float s = scroll_speed * iTime * 0.1;
    // GLSL-safe modulo that also handles negative speeds.
    return s - span * floor(s / span);
}

// Binary glyph coverage at a position in layout units (already including the
// alignment offset and the scroll offset).
float glyphMaskAt(vec2 p)
{
    float col_unit = 5.0;                 // 5 columns per glyph
    float pitch = glyphPitch();
    int count = activeCharCount();
    vec2 scaled = vec2(p.x * col_unit, p.y * col_unit);

    for (int g = 0; g < 16; g++) {
        if (g >= count) break;

        float cell_x = scaled.x - float(g) * pitch * col_unit;
        if (cell_x < 0.0 || cell_x >= 5.0)
            continue;

        int gcol = int(floor(cell_x));
        int grow = int(floor(clamp(scaled.y, 0.0, 6.999)));
        if (grow < 0) grow = 0;
        if (grow > 6) grow = 6;

        if (glyphLit(charCodeAt(g), gcol, grow))
            return 1.0;
    }
    return 0.0;
}

// Wrapped coverage: sample the text and its copies one wrap-span to the left
// and right. This makes the line re-enter from the front as soon as its last
// character has left the image, with no gap and no jump.
float wrappedMask(vec2 p, float span)
{
    float m = glyphMaskAt(p);
    if (m > 0.5) return 1.0;
    m = glyphMaskAt(vec2(p.x - span, p.y));
    if (m > 0.5) return 1.0;
    m = glyphMaskAt(vec2(p.x + span, p.y));
    if (m > 0.5) return 1.0;
    return 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    float line_start = lineStartX();
    float span = scrollSpanUnits();
    float scroll_off = scrollOffsetUnits();

    // Work in glyph-normalized space; p is measured in layout units.
    vec2 p = toGlyphSpace(uv);
    p.x = p.x - line_start + scroll_off;

    float mask = wrappedMask(p, span);

    // One screen pixel expressed in layout units (per axis, since width and
    // height are scaled independently).
    vec2 pixel = vec2(1.0 / max(iResolution.x * text_width, 1.0),
                      1.0 / max(iResolution.y * text_height, 1.0));

    // Style / glow: build a soft coverage from the binary mask using a small
    // neighbourhood sample for a halo.
    float coverage = mask;
    if (style == 1) {
        // Glow: add a radial-ish halo around lit pixels by sampling neighbours.
        float halo = 0.0;
        vec2 step = pixel * (1.0 + glow_strength * 3.0);
        for (int ox = -2; ox <= 2; ox++) {
            for (int oy = -2; oy <= 2; oy++) {
                vec2 sp = p + vec2(float(ox), float(oy)) * step;
                if (wrappedMask(sp, span) > 0.5) {
                    float d = float(ox * ox + oy * oy);
                    halo += exp(-d / max(glow_strength * 4.0, 0.5));
                }
            }
        }
        coverage = clamp(mask + halo * 0.25, 0.0, 1.0);
    }
    else if (style == 2) {
        // Outline: lit pixel whose neighbour (up/down/left/right) is unlit.
        if (mask > 0.5) {
            bool edge = false;
            vec2 dirs[4];
            dirs[0] = vec2(1.0, 0.0);
            dirs[1] = vec2(-1.0, 0.0);
            dirs[2] = vec2(0.0, 1.0);
            dirs[3] = vec2(0.0, -1.0);
            for (int k = 0; k < 4; k++) {
                vec2 sp = p + dirs[k] * pixel * 0.5;
                if (wrappedMask(sp, span) < 0.5) { edge = true; break; }
            }
            coverage = edge ? 1.0 : 0.12; // faint fill inside for outline look
        }
    }

    coverage = clamp(coverage * text_opacity, 0.0, 1.0);

    vec3 col = mix(background_color, text_color, coverage);
    float alpha = clamp(max(coverage, background_opacity), 0.0, 1.0);

    fragColor = vec4(col, alpha);
}
