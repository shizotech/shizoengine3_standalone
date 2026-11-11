// ---- SlitScan: what the passes share ----
// Time displacement: every part of the picture shows another moment. Pass C keeps the last frames of the input in one
// big texture (an atlas of tiles, 3840 x 2160: 16 frames of 960 x 540 up to 144 of 320 x 180) and writes the newest
// over the oldest; its last rows hold the state (the tile of the newest frame, the count towards Record every, how
// many tiles are filled, the layout). __init__ picks for every pixel how far back it looks: by its row, its column,
// a direction, the distance from a centre, the brightness of the input or of the Time map, and reads that frame.
// Slit stack is the slit-scan camera instead: pass F adds one slit of the input a frame at its edge and pushes the
// rest along, so one axis of the picture becomes time (full size, as long as the picture is wide).
// Pass N asks whether something is linked into Time map (an optional input is tested only in a pass where it is the
// only input, SHADER_GUIDE.MD section 5). S keeps the music.
#include music.glsl

//@enum options=(Rows, Columns, Diagonal, Radial, Brightness, Time map, Slit stack) value=0
uniform int time_mode;              // what decides how far back a part of the picture looks
//@enum options=(16 frames, 36 frames, 64 frames, 100 frames, 144 frames) value=2
uniform int cache_frames;           // the history: 16 of 960 x 540, 36 of 640 x 360, 64 of 480 x 270, 100 of 384 x 216, 144 of 320 x 180
//@int min=1 max=8 value=2
uniform int record_every;           // keep every n-th frame: a longer history, choppier
//@button
uniform bool freeze;                // stops recording: the history holds still (map it to a MIDI pad)

//@enum options=(Left, Right, Up, Down, Out) value=0
uniform int scan_direction;         // Slit stack: where the picture runs (out: from the middle to both sides)
//@slider min=0.0 max=1.0 value=0.5
uniform float slit_position;        // Slit stack: where the slit cuts the input (a column, or a row for up and down)
//@slider min=0.25 max=16.0 value=2.0
uniform float scan_speed;           // Slit stack: pixels a frame at 1080p (each frame adds a slit this wide)

const ivec2 ATLAS = ivec2(3840, 2160);
const int STATE_ROW = 2160;

int gridSize() {
    return cache_frames == 0 ? 4 : (cache_frames == 1 ? 6 : (cache_frames == 2 ? 8 : (cache_frames == 3 ? 10 : 12)));
}

// The state as written by C: x head tile, y record counter, z filled tiles, w layout + 1
ivec4 readState(sampler2D cache) {
    return ivec4(floor(texelFetch(cache, ivec2(0, STATE_ROW), 0) * 255.0 + 0.5));
}

float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
