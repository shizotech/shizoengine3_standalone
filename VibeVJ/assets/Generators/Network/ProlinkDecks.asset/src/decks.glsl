#version 330 core

// CDJ deck view (like ShowKontrol): per deck a header panel with preview waveform on top,
// stacked scrolling detail waveforms below. Texts are drawn by the generator with nanovg.
// Texture layout per deck: see shzmodule_prolink/README.md ("Waveform texture").

uniform sampler2D deck1;
uniform sampler2D deck2;
uniform sampler2D deck3;
uniform sampler2D deck4;
uniform vec4 info1;   // rows, detail columns, preview columns, style (0 none, 1 3band, 2 color)
uniform vec4 info2;
uniform vec4 info3;
uniform vec4 info4;
uniform vec4 play1;   // detail column at the playhead, progress 0..1, master, on air
uniform vec4 play2;
uniform vec4 play3;
uniform vec4 play4;
uniform vec4 pstyle;  // style of the preview waveform per deck (x = deck 1 ...), may differ from the detail
uniform float decks;  // 1..4
uniform float zoom;   // detail columns across a lane (150 per second)

// Layout, keep in sync with layout() in __init__.shio (fractions of the output)
const float TOP  = 0.38;   // height of the panel area
const float GAP  = 0.012;
const float PAD  = 0.006;
const float HEAD = 0.42;   // header part of a panel
const float LM   = 0.045;  // lane margin left (deck number)
const float RM   = 0.075;  // lane margin right (pitch)

const vec3 BG        = vec3(0.035, 0.037, 0.045);
const vec3 PANEL     = vec3(0.075, 0.078, 0.095);
const vec3 LANE      = vec3(0.055, 0.057, 0.07);
const vec3 LOW       = vec3(0.13, 0.33, 0.85);
const vec3 MID       = vec3(0.95, 0.67, 0.24);
const vec3 HIGH      = vec3(1.0);
const vec3 PLAYHEAD  = vec3(1.0, 0.16, 0.16);
const vec3 MASTER    = vec3(1.0, 0.62, 0.1);

float LW = 1.0; // line width in pixels, scales with the output height (set in main)

vec4 fetch(int d, ivec2 p)
{
	if (d == 0) return texelFetch(deck1, p, 0);
	if (d == 1) return texelFetch(deck2, p, 0);
	if (d == 2) return texelFetch(deck3, p, 0);
	return texelFetch(deck4, p, 0);
}

vec4 info(int d) { return d == 0 ? info1 : d == 1 ? info2 : d == 2 ? info3 : info4; }
vec4 play(int d) { return d == 0 ? play1 : d == 1 ? play2 : d == 2 ? play3 : play4; }
float preview_style(int d) { return d == 0 ? pstyle.x : d == 1 ? pstyle.y : d == 2 ? pstyle.z : pstyle.w; }

vec4 detail_px(int d, int c)          { return fetch(d, ivec2(c % 4096, c / 4096)); }
vec4 detail_mk(int d, int c, int rows) { return fetch(d, ivec2(c % 4096, rows + c / 4096)); }
vec4 preview_px(int d, int c, int rows) { return fetch(d, ivec2(c, 2 * rows)); }
vec4 preview_mk(int d, int c, int rows) { return fetch(d, ivec2(c, 2 * rows + 1)); }

bool bit(vec4 marker, int flag) { return (int(marker.a * 255.0 + 0.5) & flag) != 0; }

// Color of the waveform at height h (0 = base, 1 = top), alpha 0 = nothing
vec4 wave(vec4 px, float style, float h)
{
	if (style < 1.5)
	{
		// 3-band: stacked, front layer wins (bass in front)
		if (h <= px.r) return vec4(LOW, 1.0);
		if (h <= px.g) return vec4(MID, 1.0);
		if (h <= px.b) return vec4(HIGH, 1.0);
		return vec4(0.0);
	}
	return h <= px.a ? vec4(px.rgb, 1.0) : vec4(0.0);
}

// Highest column in [c0, c1) (heights only grow, so the channel-wise maximum is the peak)
vec4 detail_peak(int d, float c0, float c1, int count)
{
	vec4 best = vec4(0.0);
	int a = int(floor(c0));
	int b = max(a + 1, int(floor(c1)));
	int step = max(1, (b - a) / 6);
	for (int c = a; c < b; c += step)
		if (c >= 0 && c < count)
			best = max(best, detail_px(d, c));
	return best;
}

vec3 draw_lane(int d, vec2 p, vec2 size, vec3 color)
{
	vec4 inf = info(d);
	vec4 pl = play(d);
	int rows = int(inf.x);
	int count = int(inf.y);

	color = LANE;
	if (inf.w < 0.5)
		return color;

	float cols_per_px = zoom / size.x;
	float col = pl.x + (p.x / size.x - 0.5) * zoom;
	float h = abs(p.y / size.y - 0.5) * 2.0; // mirrored around the middle

	// Loop regions
	if (col >= 0.0 && col < float(count) && bit(detail_mk(d, int(col), rows), 0x10))
		color = mix(color, vec3(0.6, 0.35, 0.05), 0.35);

	vec4 w = wave(detail_peak(d, col - 0.5 * cols_per_px, col + 0.5 * cols_per_px, count), inf.w, h);
	color = mix(color, w.rgb, w.a);

	// Beats (ticks at the edges, downbeats red) and cues (full line in the cue color)
	// At most 8 columns around the pixel centre (zoomed out there would be hundreds, and a window starting
	// at the left edge would miss the markers that belong to this pixel)
	float r = min(LW * cols_per_px, 4.0);
	for (int k = int(ceil(col - r)); k < int(ceil(col + r)); k++)
	{
		if (k < 0 || k >= count)
			continue;
		vec4 m = detail_mk(d, k, rows);
		bool inside = abs(float(k) - col) <= 0.5 * LW * cols_per_px;
		if (bit(m, 0x20))
			color = mix(color, m.rgb, 0.9);
		if (inside && bit(m, 0x80) && h > 0.8)
			color = bit(m, 0x40) ? vec3(1.0, 0.25, 0.2) : vec3(0.85);
	}

	// Playhead in the middle
	if (abs(p.x - size.x * 0.5) < LW)
		color = PLAYHEAD;
	return color;
}

vec3 draw_panel(int d, vec2 p, vec2 size, vec3 color)
{
	vec4 inf = info(d);
	vec4 pl = play(d);
	int rows = int(inf.x);
	int count = int(inf.z);

	color = PANEL;
	float head = size.y * HEAD;

	// Header: accent line on the left (orange = tempo master, red = on air)
	if (p.y < head)
	{
		if (p.x < 3.0 * LW)
			color = pl.z > 0.5 ? MASTER : pl.w > 0.5 ? vec3(0.8, 0.12, 0.12) : vec3(0.25);
		return color;
	}

	float ps = preview_style(d);
	if (ps < 0.5 || count <= 0)
		return color * 0.8;

	// Preview: bars from the bottom over the whole track
	vec2 q = vec2(p.x / size.x, (p.y - head) / (size.y - head));
	int c = clamp(int(q.x * float(count)), 0, count - 1);
	vec4 w = wave(preview_px(d, c, rows), ps, 1.0 - q.y);
	vec3 wc = w.rgb;
	if (q.x < pl.y)
		wc *= 0.45; // already played
	color = mix(color * 0.8, wc, w.a);

	vec4 m = preview_mk(d, c, rows);
	if (bit(m, 0x10))
		color = mix(color, vec3(0.6, 0.35, 0.05), 0.3);
	if (bit(m, 0x20) && q.y < 0.3)
		color = m.rgb;

	if (abs(q.x - pl.y) * size.x < LW)
		color = vec3(1.0);
	return color;
}

void main()
{
	vec2 res = u_resolution;
	vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * res; // pixels, y down (like nanovg)
	vec3 color = BG;
	LW = max(1.0, res.y / 540.0);

	int n = int(decks + 0.5);
	int cols = n > 1 ? 2 : 1;
	int prows = (n + cols - 1) / cols;

	// Panels
	float ph = TOP * res.y / float(prows);
	for (int i = 0; i < n; i++)
	{
		vec2 pos = vec2((float(i % cols) / float(cols) + PAD) * res.x, float(i / cols) * ph + GAP * 0.5 * res.y);
		vec2 size = vec2((1.0 / float(cols) - 2.0 * PAD) * res.x, ph - GAP * res.y);
		vec2 p = px - pos;
		if (p.x >= 0.0 && p.y >= 0.0 && p.x < size.x && p.y < size.y)
			color = draw_panel(i, p, size, color);
	}

	// Lanes
	float top = (TOP + GAP) * res.y;
	float lh = (res.y - top) / float(n);
	for (int i = 0; i < n; i++)
	{
		vec2 pos = vec2(LM * res.x, top + float(i) * lh);
		vec2 size = vec2((1.0 - LM - RM) * res.x, lh - GAP * 0.5 * res.y);
		vec2 p = px - pos;
		if (p.x >= 0.0 && p.y >= 0.0 && p.x < size.x && p.y < size.y)
			color = draw_lane(i, p, size, color);
	}

	fragColor = vec4(color, 1.0);
}
