#version 330 core

// CDJ deck view (like ShowKontrol). Two layouts:
//   mode 0: a row of deck panels (header + preview of the whole track) on top, scrolling lanes below
//   mode 1: lanes only, each with an info column on the left and an optional overview bar at the bottom
// Texts are drawn by the generator with nanovg. All layout numbers come from layout() in __init__.shio,
// so text and graphics always match. Texture layout per deck: see shzmodule_prolink/README.md.

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

uniform vec4 lanes;     // deck (0..3) shown in lane 1..4, -1 = none
uniform float nlanes;   // 1..4
uniform float zoom;     // detail columns across the waveform area (150 per second)
uniform float playhead; // position of the playhead in the waveform area, 0..1 (0.5 = centre)
uniform float top;      // height of the panel row (fraction of the output), 0 = no panels
uniform float info_w;   // width of the info column left of each lane (fraction of the output width)
uniform float right_w;  // free margin right of each lane (fraction of the output width)
uniform float pbar;     // overview bar at the bottom of each lane (fraction of the lane height), 0 = off
uniform float hist_w;   // history column at the right (fraction of the output width), 0 = off

// Colors of the STYLE (CDJ or VibeVJ), set by the generator every frame
uniform vec3 c_bg;        // behind everything
uniform vec3 c_panel;     // deck panels, info columns, history column
uniform vec3 c_lane;      // behind the detail waveform
uniform vec3 c_low;       // 3-band waveform: bass, mids, highs
uniform vec3 c_mid;
uniform vec3 c_high;
uniform vec3 c_playhead;
uniform vec3 c_master;    // stripe of the tempo master
uniform vec3 c_on_air;    // stripe of a channel that is open on the mixer
uniform vec3 c_idle;      // stripe otherwise
uniform vec3 c_loop;
uniform vec3 c_tick;      // beat ticks
uniform vec3 c_down;      // downbeat ticks
uniform float radius;     // corner radius of panels, lanes and the history column (pixels), 0 = square
uniform float stripe;     // width of the stripe left of panels and lanes (line widths)

const float GAP  = 0.012;  // between panels/lanes (fraction of the output height)
const float PAD  = 0.006;  // outer margin
const float HEAD = 0.42;   // text part of a panel
const float ROOM = 0.84;   // the detail waveform uses this much of the half height; above it beat ticks and cue flags

#define BG       c_bg
#define PANEL    c_panel
#define LANE     c_lane
#define LOW      c_low
#define MID      c_mid
#define HIGH     c_high
#define PLAYHEAD c_playhead
#define MASTER   c_master
#define ON_AIR   c_on_air
#define LOOP     c_loop

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
int lane_deck(int i) { return int(i == 0 ? lanes.x : i == 1 ? lanes.y : i == 2 ? lanes.z : lanes.w); }

vec4 detail_px(int d, int c)          { return fetch(d, ivec2(c % 4096, c / 4096)); }
vec4 detail_mk(int d, int c, int rows) { return fetch(d, ivec2(c % 4096, rows + c / 4096)); }
vec4 preview_px(int d, int c, int rows) { return fetch(d, ivec2(c, 2 * rows)); }
vec4 preview_mk(int d, int c, int rows) { return fetch(d, ivec2(c, 2 * rows + 1)); }

bool bit(vec4 marker, int flag) { return (int(marker.a * 255.0 + 0.5) & flag) != 0; }

// Share of the pixel below the edge `edge` (h and aa in the same units, aa = one pixel): soft edges
float cover(float edge, float h, float aa) { return clamp((edge - h) / aa + 0.5, 0.0, 1.0); }

// Color of the waveform at height h (0 = base, 1 = top) with anti-aliased edges, alpha = coverage.
// The bands get a little brighter towards their outer edge, so the shape reads at a glance.
vec4 wave(vec4 px, float style, float h, float aa)
{
	if (style < 1.5)
	{
		// 3-band: stacked, front layer wins (bass in front)
		float a = cover(px.b, h, aa) * clamp(px.b / aa, 0.0, 1.0); // no hairline where there is no signal
		if (a <= 0.0)
			return vec4(0.0);
		vec3 c = HIGH * (0.78 + 0.22 * clamp((h - px.g) / max(px.b - px.g, aa), 0.0, 1.0));
		c = mix(c, MID * (0.82 + 0.18 * clamp((h - px.r) / max(px.g - px.r, aa), 0.0, 1.0)), cover(px.g, h, aa));
		c = mix(c, LOW * (0.75 + 0.35 * clamp(h / max(px.r, aa), 0.0, 1.0)), cover(px.r, h, aa));
		return vec4(c, a);
	}
	return vec4(px.rgb * (0.8 + 0.25 * clamp(h / max(px.a, aa), 0.0, 1.0)), cover(px.a, h, aa) * clamp(px.a / aa, 0.0, 1.0));
}

// Highest column in [c0, c1) (heights only grow, so the channel-wise maximum is the peak)
vec4 column_peak(int d, float c0, float c1, int count, int rows, bool preview)
{
	vec4 best = vec4(0.0);
	int a = int(floor(c0));
	int b = max(a + 1, int(ceil(c1)));
	int step = max(1, (b - a) / 8);
	for (int c = a; c < b; c += step)
		if (c >= 0 && c < count)
			best = max(best, preview ? preview_px(d, c, rows) : detail_px(d, c));
	return best;
}

// Waveform column at a fractional position: zoomed in it interpolates between the columns
// (smooth curves instead of steps), zoomed out it takes the peak of the columns under the pixel
vec4 detail_sample(int d, float col, float cols_per_px, int count)
{
	if (cols_per_px > 1.0)
		return column_peak(d, col - 0.5 * cols_per_px, col + 0.5 * cols_per_px, count, 0, false);
	float c = col - 0.5;
	int a = int(floor(c));
	vec4 p0 = a >= 0 && a < count ? detail_px(d, a) : vec4(0.0);
	vec4 p1 = a + 1 >= 0 && a + 1 < count ? detail_px(d, a + 1) : vec4(0.0);
	return mix(p0, p1, c - float(a));
}

vec3 accent(vec4 pl)
{
	return pl.z > 0.5 ? MASTER : pl.w > 0.5 ? ON_AIR : c_idle;
}

// Inside a rectangle of `size` with rounded corners (radius r)? p from its top left corner
bool inside(vec2 p, vec2 size, float r)
{
	if (r <= 0.0)
		return true;
	vec2 q = abs(p - 0.5 * size) - (0.5 * size - vec2(r));
	return length(max(q, 0.0)) <= r;
}

// Scrolling detail waveform; the playhead sits at `playhead` of the width, the past left of it is dimmed.
// Without a waveform the lane stays empty (no playhead either). Cue flags are drawn by the generator.
vec3 draw_detail(int d, vec2 p, vec2 size)
{
	vec4 inf = info(d);
	vec4 pl = play(d);
	int rows = int(inf.x);
	int count = int(inf.y);
	vec3 color = LANE;
	float head_x = size.x * playhead;

	if (inf.w > 0.5 && count > 0)
	{
		float cols_per_px = zoom / size.x;
		float col = pl.x + (p.x / size.x - playhead) * zoom;
		float edge_h = abs(p.y / size.y - 0.5) * 2.0; // mirrored around the middle, 1 = lane edge
		float h = edge_h / ROOM;
		float aa = 2.0 / (size.y * ROOM);
		int c = int(floor(col));
		vec4 mk = c >= 0 && c < count ? detail_mk(d, c, rows) : vec4(0.0);

		// Loops: tinted, with a bright band at the top and bottom edge
		bool in_loop = bit(mk, 0x10);
		if (in_loop)
			color = mix(color, LOOP, 0.16);

		// Beat grid: ticks at the edges (downbeats red), every bar also a faint line through the lane
		float r = min(LW * cols_per_px, 4.0);
		float tick = 0.0;
		bool down = false;
		for (int k = int(ceil(col - r)); k < int(ceil(col + r)); k++)
		{
			if (k < 0 || k >= count)
				continue;
			vec4 m = detail_mk(d, k, rows);
			if (bit(m, 0x80) && abs(float(k) - col) <= 0.5 * LW * cols_per_px)
			{
				tick = 1.0;
				down = down || bit(m, 0x40);
			}
		}
		if (tick > 0.0 && down)
			color = mix(color, vec3(1.0), 0.09);

		vec4 w = wave(detail_sample(d, col, cols_per_px, count), inf.w, h, aa);
		color = mix(color, w.rgb, w.a);

		if (tick > 0.0 && edge_h > 0.86)
			color = down ? c_down : c_tick;
		if (in_loop && edge_h > 1.0 - 8.0 * LW / size.y)
			color = LOOP;

		// What has already played is less important than what comes
		if (p.x < head_x)
			color = mix(LANE, color, 0.45);

		// Playhead with small triangles at the top and bottom
		float dx = abs(p.x - head_x);
		float edge = min(p.y, size.y - p.y);
		if (dx < LW || dx < 5.0 * LW - edge)
			color = PLAYHEAD;
	}
	return color;
}

// Whole track: bars from the bottom, played part darker, loops tinted, white progress line.
// Cue marks are drawn by the generator.
vec3 draw_preview(int d, vec2 p, vec2 size, vec3 base)
{
	vec4 inf = info(d);
	vec4 pl = play(d);
	int rows = int(inf.x);
	int count = int(inf.z);
	float style = preview_style(d);
	vec3 color = base;
	if (style < 0.5 || count <= 0)
		return color;

	vec2 q = p / size;
	float c0 = p.x / size.x * float(count);
	float c1 = (p.x + 1.0) / size.x * float(count);
	int c = clamp(int(c0), 0, count - 1);

	vec4 m = preview_mk(d, c, rows);
	if (bit(m, 0x10))
		color = mix(color, LOOP, 0.22);

	vec4 w = wave(column_peak(d, c0, c1, count, rows, true), style, 1.0 - q.y, 1.0 / size.y);
	vec3 wc = w.rgb;
	if (q.x < pl.y)
		wc = mix(wc, vec3(dot(wc, vec3(0.33))), 0.4) * 0.5; // already played: darker and paler
	color = mix(color, wc, w.a);

	if (bit(m, 0x10) && q.y < 3.0 * LW / size.y)
		color = LOOP;
	if (abs(q.x - pl.y) * size.x < LW)
		color = vec3(1.0);
	return color;
}

// Panel of the panel row: text part on top (drawn by the generator), preview below
vec3 draw_panel(int d, vec2 p, vec2 size)
{
	vec4 pl = play(d);
	float head = size.y * HEAD;
	if (p.x < stripe * LW)
		return accent(pl);
	if (p.y < head || d < 0)
		return PANEL;
	return draw_preview(d, vec2(p.x, p.y - head), vec2(size.x, size.y - head), PANEL * 0.8);
}

void main()
{
	vec2 res = u_resolution;
	vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * res; // pixels, y down (like nanovg)
	vec3 color = BG;
	LW = max(1.0, res.y / 540.0);

	int n = clamp(int(nlanes + 0.5), 1, 4);
	float pad_x = PAD * res.x;
	float pad_y = PAD * res.y;
	float gap = GAP * res.y;
	float R = radius;

	// History column at the right (texts by the generator); the decks use the width left of it
	float W = res.x;
	if (hist_w > 0.0)
	{
		float cw = hist_w * res.x;
		W = res.x - cw - gap;
		vec2 p = px - vec2(res.x - pad_x - cw, pad_y);
		if (p.x >= 0.0 && p.y >= 0.0 && p.x < cw && p.y < res.y - 2.0 * pad_y)
		{
			fragColor = vec4(inside(p, vec2(cw, res.y - 2.0 * pad_y), R) ? PANEL : BG, 1.0);
			return;
		}
	}

	// Panel row: one panel per lane, side by side
	if (top > 0.0)
	{
		float pw = (W - 2.0 * pad_x - float(n - 1) * gap) / float(n);
		float ph = top * res.y - pad_y;
		for (int i = 0; i < n; i++)
		{
			vec2 p = px - vec2(pad_x + float(i) * (pw + gap), pad_y);
			if (p.x >= 0.0 && p.y >= 0.0 && p.x < pw && p.y < ph && inside(p, vec2(pw, ph), R))
			{
				int d = lane_deck(i);
				color = d < 0 ? PANEL : draw_panel(d, p, vec2(pw, ph));
			}
		}
	}

	// Lanes
	float y0 = top > 0.0 ? top * res.y + gap : pad_y;
	float lh = (res.y - pad_y - y0 - float(n - 1) * gap) / float(n);
	float iw = info_w * res.x;
	float rw = right_w * res.x;
	for (int i = 0; i < n; i++)
	{
		vec2 p = px - vec2(pad_x, y0 + float(i) * (lh + gap));
		float lw = W - 2.0 * pad_x;
		if (p.x < 0.0 || p.y < 0.0 || p.x >= lw || p.y >= lh)
			continue;
		int d = lane_deck(i);
		vec4 pl = d < 0 ? vec4(0.0) : play(d);

		// Info column (texts by the generator) with the deck's accent on the left
		if (p.x < iw)
		{
			if (inside(p, vec2(iw, lh), R))
				color = p.x < stripe * LW ? accent(pl) : PANEL;
			continue;
		}
		// Free margin right (pitch in the panel layout)
		if (p.x >= lw - rw)
		{
			color = BG;
			continue;
		}

		vec2 q = vec2(p.x - iw - gap * 0.5, p.y);
		vec2 size = vec2(lw - rw - iw - gap * 0.5, lh);
		if (q.x < 0.0 || !inside(q, size, R))
		{
			color = BG;
			continue;
		}
		if (d < 0)
		{
			color = LANE;
			continue;
		}

		// Optional overview bar at the bottom (only with a preview, empty lanes stay plain)
		float bar = pbar * lh;
		if (bar > 0.0 && info(d).z > 0.5 && preview_style(d) > 0.5)
		{
			float split = lh - bar;
			if (q.y >= split + LW)
			{
				color = draw_preview(d, vec2(q.x, q.y - split - LW), vec2(size.x, bar - LW), PANEL * 0.8);
				continue;
			}
			if (q.y >= split)
			{
				color = BG;
				continue;
			}
			size.y = split;
		}
		color = draw_detail(d, q, size);
	}

	fragColor = vec4(color, 1.0);
}
