#version 330 core

// CDJ deck view (like ShowKontrol and the CDJ-3000), up to six decks. Two layouts:
//   mode 0: a row of deck panels (header + preview of the whole track) on top, scrolling lanes below; five and six
//           decks put the panels in two rows of three
//   mode 1: lanes only, each with an info column on the left and an optional overview bar at the bottom
// Texts are drawn by the generator with nanovg. All layout numbers come from layout() in __init__.shio,
// so text and graphics always match. Texture layout per deck: see modules/shzmodule_prolink/README.md.
//
// The view is content (Shizo UI principle 1): waveforms, beat grid, cues, loops and phrases keep the colours of the
// STYLE. Its chrome (background, panels, lanes, the state stripe) uses the Shizo UI tokens below in both styles. The
// artwork is drawn here where the overlay laid it out (artr*); the live ring and badges are drawn by the overlay.

// Shizo UI tokens (design/tokens.json, version 0.3.0). The overlay in __init__.shio uses the same values (UI_*).
const vec3 UI_CANVAS  = vec3(11.0, 11.0, 12.0) / 255.0;    // canvas: behind everything, gaps between panels and lanes
const vec3 UI_FIELD   = vec3(14.0, 14.0, 15.0) / 255.0;    // field: behind the waveforms (lanes, previews)
const vec3 UI_SURFACE = vec3(19.0, 19.0, 20.0) / 255.0;    // surface: deck panels, info columns, history column
const vec3 UI_CONTROL = vec3(37.0, 37.0, 40.0) / 255.0;    // control: stripe of a deck that is neither on air nor master
const vec3 UI_TEXT    = vec3(237.0, 237.0, 237.0) / 255.0; // text: stripe of the tempo master, progress line
const vec3 UI_LIVE    = vec3(63.0, 207.0, 142.0) / 255.0;  // live (= on): stripe of a deck that is on air
const vec4 UI_LINE    = vec4(1.0, 1.0, 1.0, 0.07);         // line: white 7 %, bar lines through the lane

// Up to six decks (CDJ-3000 / Pro DJ Link players 1-6). GLSL 330 indexes samplers only with constants: one sampler each.
uniform sampler2D deck1;
uniform sampler2D deck2;
uniform sampler2D deck3;
uniform sampler2D deck4;
uniform sampler2D deck5;
uniform sampler2D deck6;
uniform sampler2D art1;  // artwork of the loaded track (JPEG from the player), drawn into art_rect
uniform sampler2D art2;
uniform sampler2D art3;
uniform sampler2D art4;
uniform sampler2D art5;
uniform sampler2D art6;
uniform vec4 info1;   // rows, detail columns, preview columns, style (0 none, 1 3band, 2 color)
uniform vec4 info2;
uniform vec4 info3;
uniform vec4 info4;
uniform vec4 info5;
uniform vec4 info6;
uniform vec4 play1;   // detail column at the playhead, progress 0..1, master, live (on air, see live_of() in __init__.shio)
uniform vec4 play2;
uniform vec4 play3;
uniform vec4 play4;
uniform vec4 play5;
uniform vec4 play6;
uniform vec4 artr1;   // where the overlay put the artwork of the deck: x, y, w, h in output pixels; w = 0: no artwork
uniform vec4 artr2;
uniform vec4 artr3;
uniform vec4 artr4;
uniform vec4 artr5;
uniform vec4 artr6;
uniform vec4 pstyle;  // style of the preview waveform per deck (x = deck 1 ... w = deck 4), may differ from the detail
uniform vec2 pstyle2; // decks 5 and 6

uniform vec4 lanes;     // deck (0..5) shown in lane 1..4, -1 = none
uniform vec2 lanes2;    // lanes 5 and 6
uniform float nlanes;   // 1..6
uniform float zoom;     // detail columns across the waveform area (150 per second; more seconds on wide outputs)
uniform float playhead; // position of the playhead in the waveform area, 0..1 (0.5 = centre)
uniform float top;      // height of the panel row (fraction of the output), 0 = no panels
uniform float head;     // text part of a panel (fraction of the panel height; 0.42, more in flat strips)
uniform float info_w;   // width of the info column left of each lane (fraction of the output width)
uniform float right_w;  // free margin right of each lane (fraction of the output width)
uniform float pbar;     // overview bar at the bottom of each lane (fraction of the lane height), 0 = off
uniform float hist_w;   // history column at the right (fraction of the output width), 0 = off
uniform float pad_w;    // outer margin left and right (fraction of the output width; PAD of the height at 1920 x 1080)

// Content colours of the STYLE (CDJ or VibeVJ), set by the generator every frame
uniform vec3 c_low;       // 3-band waveform: bass, mids, highs
uniform vec3 c_mid;
uniform vec3 c_high;
uniform vec3 c_playhead;
uniform vec3 c_loop;
uniform vec3 c_tick;      // beat ticks
uniform vec3 c_down;      // downbeat ticks
uniform float radius;     // corner radius of panels, lanes and the history column (pixels; radius.window = 4 px at 1080)
uniform float stripe;     // width of the state stripe left of panels and lanes (line widths)

const float GAP  = 0.012;  // between panels/lanes (fraction of the output height)
const float PAD  = 0.006;  // outer margin top and bottom (left and right: pad_w)
const float ROOM = 0.84;   // the detail waveform uses this much of the half height; above it beat ticks and cue flags

#define BG       UI_CANVAS
#define PANEL    UI_SURFACE
#define LANE     UI_FIELD
#define LOW      c_low
#define MID      c_mid
#define HIGH     c_high
#define PLAYHEAD c_playhead
#define LOOP     c_loop

float LW = 1.0; // line width in pixels, scales with the output height, narrow outputs with their width (set in main)

vec4 fetch(int d, ivec2 p)
{
	if (d == 0) return texelFetch(deck1, p, 0);
	if (d == 1) return texelFetch(deck2, p, 0);
	if (d == 2) return texelFetch(deck3, p, 0);
	if (d == 3) return texelFetch(deck4, p, 0);
	if (d == 4) return texelFetch(deck5, p, 0);
	return texelFetch(deck6, p, 0);
}

vec4 info(int d) { return d == 0 ? info1 : d == 1 ? info2 : d == 2 ? info3 : d == 3 ? info4 : d == 4 ? info5 : info6; }
vec4 play(int d) { return d == 0 ? play1 : d == 1 ? play2 : d == 2 ? play3 : d == 3 ? play4 : d == 4 ? play5 : play6; }
vec4 art_rect(int d) { return d == 0 ? artr1 : d == 1 ? artr2 : d == 2 ? artr3 : d == 3 ? artr4 : d == 4 ? artr5 : artr6; }
float preview_style(int d)
{
	return d == 0 ? pstyle.x : d == 1 ? pstyle.y : d == 2 ? pstyle.z : d == 3 ? pstyle.w : d == 4 ? pstyle2.x : pstyle2.y;
}
int lane_deck(int i)
{
	return int(i == 0 ? lanes.x : i == 1 ? lanes.y : i == 2 ? lanes.z : i == 3 ? lanes.w : i == 4 ? lanes2.x : lanes2.y);
}

// Artwork of deck d at uv (0..1, y down), cropped to a square from its middle (most covers are square already)
vec3 art_texel(int d, vec2 uv)
{
	ivec2 ts = d == 0 ? textureSize(art1, 0) : d == 1 ? textureSize(art2, 0) : d == 2 ? textureSize(art3, 0)
		: d == 3 ? textureSize(art4, 0) : d == 4 ? textureSize(art5, 0) : textureSize(art6, 0);
	vec2 k = vec2(min(float(ts.y) / float(ts.x), 1.0), min(float(ts.x) / float(ts.y), 1.0));
	uv = 0.5 + (uv - 0.5) * k;
	if (d == 0) return texture(art1, uv).rgb;
	if (d == 1) return texture(art2, uv).rgb;
	if (d == 2) return texture(art3, uv).rgb;
	if (d == 3) return texture(art4, uv).rgb;
	if (d == 4) return texture(art5, uv).rgb;
	return texture(art6, uv).rgb;
}

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

// State stripe left of panels and lanes: tempo master = light, else live = live green, else quiet. Master first, so
// the master stays visible when several channels are open (a live deck also gets the live ring and the Live badge of
// the overlay). The colour is not the only signal: the overlay writes "Live" and "Master".
vec3 stripe_color(vec4 pl)
{
	return pl.z > 0.5 ? UI_TEXT : pl.w > 0.5 ? UI_LIVE : UI_CONTROL;
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
			color = mix(color, UI_LINE.rgb, UI_LINE.a);

		vec4 w = wave(detail_sample(d, col, cols_per_px, count), inf.w, h, aa);
		color = mix(color, w.rgb, w.a);

		if (tick > 0.0 && edge_h > 0.86)
			color = down ? c_down : c_tick;
		if (in_loop && edge_h > 1.0 - 8.0 * LW / size.y)
			color = LOOP;

		// What has already played is less important than what comes: half bright
		if (p.x < head_x)
			color = mix(LANE, color, 0.5);

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
		color = UI_TEXT;
	return color;
}

// Panel of the panel row: text part on top (drawn by the generator), preview below
vec3 draw_panel(int d, vec2 p, vec2 size)
{
	vec4 pl = play(d);
	float hy = size.y * head;
	if (p.x < stripe * LW)
		return stripe_color(pl);
	if (p.y < hy || d < 0)
		return PANEL;
	return draw_preview(d, vec2(p.x, p.y - hy), vec2(size.x, size.y - hy), UI_FIELD);
}

void main()
{
	vec2 res = u_resolution;
	vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * res; // pixels, y down (like nanovg)
	vec3 color = BG;
	LW = max(1.0, min(res.y / 540.0, res.x / 960.0)); // line_width() in __init__.shio

	int n = clamp(int(nlanes + 0.5), 1, 6);
	float pad_x = pad_w * res.x;
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

	// Panel row: one panel per lane, side by side; five and six decks in two rows of three (panel_cols() in __init__.shio)
	if (top > 0.0)
	{
		int cols = n > 4 ? (n + 1) / 2 : n;
		int rows = n > 4 ? 2 : 1;
		float pw = (W - 2.0 * pad_x - float(cols - 1) * gap) / float(cols);
		float ph = (top * res.y - pad_y - float(rows - 1) * gap) / float(rows);
		for (int i = 0; i < n; i++)
		{
			vec2 p = px - vec2(pad_x + float(i % cols) * (pw + gap), pad_y + float(i / cols) * (ph + gap));
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

		// Info column (texts by the generator) with the deck's state stripe on the left
		if (p.x < iw)
		{
			if (inside(p, vec2(iw, lh), R))
				color = p.x < stripe * LW ? stripe_color(pl) : PANEL;
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
				color = draw_preview(d, vec2(q.x, q.y - split - LW), vec2(size.x, bar - LW), UI_FIELD);
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

	// Artwork where the overlay laid it out (panel text part or info column), corners like the badges
	for (int i = 0; i < n; i++)
	{
		int d = lane_deck(i);
		if (d < 0)
			continue;
		vec4 r = art_rect(d);
		vec2 p = px - r.xy;
		if (r.z > 0.5 && p.x >= 0.0 && p.y >= 0.0 && p.x < r.z && p.y < r.w && inside(p, r.zw, 1.5 * LW))
			color = art_texel(d, p / r.zw);
	}

	fragColor = vec4(color, 1.0);
}
