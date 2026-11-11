/*
 * Dither: a native VibeVJ asset in plain C (issue #201) that processes a picture on the CPU, built only against
 * shz_abi.h (C ABI 1.3: picture inputs and text controls).
 *
 * Whatever is linked into its input (a shader, a video, a camera, ...) is brought down to a few colours the way old
 * computers and handhelds did it: ordered (Bayer) dithering or error diffusion (Floyd-Steinberg) to a palette given as
 * text ("#0f380f #306230 #8bac0f #9bbc0f", the colours of the Game Boy). The engine reads the input back from the GPU at
 * 320 x 180 pixels (the size the input asks for below) and gives it to update() / render() without a copy; the picture
 * is 320 x 180 as well, the engine scales it to the render size. Two value outputs: the mean brightness of the input
 * and the share of the picture in the darkest colour of the palette. Without an input it dithers a test pattern.
 *
 * The walkthrough is the section "A native VibeVJ asset" of core/shizoscript3_core_cabi/README.md (Life), the parts
 * of C ABI 1.3 are under "Picture inputs and text controls".
 *
 * Build (Linux):  gcc -std=c99 -O2 -fPIC -shared -fvisibility=hidden -I<repo>/core/shizoscript3_core_cabi/include \
 *                     dither.c -o native/linux_x64/shzmodule_native_dither.so
 * or CMakeLists.txt next to this file (Linux, macOS, Windows). _testing/linux_app/build.sh, shzscript_macos/CMakeLists.txt
 * and modules/shzmodule_native_dither/shzmodule_native_dither.vcxproj build it in this repository.
 */

#include "shz_abi.h"

#include <stdlib.h>
#include <string.h>

#define DITHER_W 320
#define DITHER_H 180
#define MAX_COLOURS 16

static const shz_host_api* host = NULL;

/* ------------------------------------------------------------------------------------------- controls and values */

enum { C_METHOD, C_PIXEL, C_CONTRAST, C_BRIGHTNESS, C_SPREAD, C_PALETTE, C_COUNT };
enum { V_LUMA, V_DARK, V_COUNT };
enum { M_BAYER2, M_BAYER4, M_BAYER8, M_FLOYD, M_THRESHOLD };

#define CONTROL(kind_, name_, display_, doc_, min_, max_, value_) \
	{ sizeof(shz_control_def), kind_, name_, display_, doc_, { min_ }, { max_ }, { value_ }, NULL, 0, 0, NULL, 0, 0 }

static const shz_control_def controls[C_COUNT] = {
	{ sizeof(shz_control_def), SHZ_CONTROL_ENUM, "method", NULL, "How the colours are mixed: an ordered pattern or error diffusion",
		{ 0 }, { 0 }, { M_BAYER4 }, "Bayer 2x2,Bayer 4x4,Bayer 8x8,Floyd-Steinberg,Threshold", 0, 0, NULL, 0, 0 },
	CONTROL(SHZ_CONTROL_INT, "pixel", "Pixel size", "How many pixels of 320 x 180 make one dot", 1, 8, 2),
	CONTROL(SHZ_CONTROL_SLIDER, "contrast", NULL, "Contrast of the input before dithering", 0, 3, 1),
	CONTROL(SHZ_CONTROL_SLIDER, "brightness", NULL, "Added to the input before dithering", -0.5, 0.5, 0),
	CONTROL(SHZ_CONTROL_SLIDER, "spread", NULL, "How strong the ordered pattern is (0: none)", 0, 2, 1),
	{ sizeof(shz_control_def), SHZ_CONTROL_TEXT, "palette", NULL,
		"The colours, as #rrggbb (or #rgb) separated by spaces or commas, at most 16", { 0 }, { 0 }, { 0 }, NULL, 0, 0,
		"#0f380f #306230 #8bac0f #9bbc0f", 160, 0 },
};

static const shz_asset_value_def values[V_COUNT] = {
	{ sizeof(shz_asset_value_def), 0, "luma", "Brightness", "The mean brightness of the input, 0 to 1", 0, 1 },
	{ sizeof(shz_asset_value_def), 0, "dark", "Dark share", "The share of the picture in the darkest colour of the palette", 0, 1 },
};

static const shz_asset_input_def inputs[1] = {
	{ sizeof(shz_asset_input_def), 0, "input", "Input", "The picture to dither (read at 320 x 180)", SHZ_PIXELS_RGBA8,
		DITHER_W, DITHER_H, 0 },
};

/* ------------------------------------------------------------------------------------------------- the instance */

typedef struct dither
{
	char palette_text[160 * 4 + 1]; /* the text the palette was made from (160 characters of UTF-8) */
	float palette[MAX_COLOURS][3];
	int colours;
	int darkest;
	float work[DITHER_W * DITHER_H * 3];   /* the input after contrast / brightness, the errors of Floyd-Steinberg */
	double luma;
	double dark;
	shz_control_value last[C_COUNT];       /* the controls of the last picture */
	int drawn;                             /* a picture was drawn since the input or a control changed */
} dither;

static int hex_digit(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return -1;
}

static float luma_of(const float* rgb)
{
	return 0.2126f * rgb[0] + 0.7152f * rgb[1] + 0.0722f * rgb[2];
}

/* "#0f380f #306230, 8bac0f #fff": every valid colour; black and white when none is */
static void parse_palette(dither* d, const char* text)
{
	const char* p = text;
	int i;
	d->colours = 0;
	while (*p && d->colours < MAX_COLOURS)
	{
		const char* start;
		int len, ok = 1, v[6];
		while (*p == ' ' || *p == ',' || *p == ';' || *p == '\t')
			p++;
		if (*p == '#')
			p++;
		start = p;
		while (*p && *p != ' ' && *p != ',' && *p != ';' && *p != '\t')
			p++;
		len = (int)(p - start);
		if (len != 6 && len != 3)
			continue;
		for (i = 0; i < len; i++)
		{
			v[i] = hex_digit(start[i]);
			ok = ok && v[i] >= 0;
		}
		if (!ok)
			continue;
		for (i = 0; i < 3; i++)
			d->palette[d->colours][i] = len == 6 ? (v[i * 2] * 16 + v[i * 2 + 1]) / 255.0f : (v[i] * 17) / 255.0f;
		d->colours++;
	}
	if (d->colours == 0)
	{
		d->colours = 2;
		for (i = 0; i < 3; i++)
		{
			d->palette[0][i] = 0;
			d->palette[1][i] = 1;
		}
	}
	d->darkest = 0;
	for (i = 1; i < d->colours; i++)
		if (luma_of(d->palette[i]) < luma_of(d->palette[d->darkest]))
			d->darkest = i;
	{
		/* a copy, cut to the buffer (no strncpy: MSVC refuses it as unsafe) */
		size_t n = strlen(text);
		if (n > sizeof(d->palette_text) - 1)
			n = sizeof(d->palette_text) - 1;
		memcpy(d->palette_text, text, n);
		d->palette_text[n] = 0;
	}
}

/* The colour of the palette nearest to rgb */
static int nearest(const dither* d, const float* rgb)
{
	int i, best = 0;
	float best_d = 1e30f;
	for (i = 0; i < d->colours; i++)
	{
		const float dr = rgb[0] - d->palette[i][0], dg = rgb[1] - d->palette[i][1], db = rgb[2] - d->palette[i][2];
		const float dist = dr * dr * 0.3f + dg * dg * 0.59f + db * db * 0.11f;
		if (dist < best_d)
		{
			best_d = dist;
			best = i;
		}
	}
	return best;
}

static shz_result dither_create(shz_ctx* ctx, const shz_asset_frame* frame, void** instance_out)
{
	dither* d = (dither*)calloc(1, sizeof(dither));
	if (!d)
		return host->error(ctx, SHZ_ERR_NOMEM, "out of memory");
	parse_palette(d, frame->texts[C_PALETTE]);
	*instance_out = d;
	return SHZ_OK;
}

static void dither_destroy(void* instance, void* asset_user)
{
	(void)asset_user;
	free(instance);
}

/* The input (or the test pattern) into work: one value per dot of the pixel size, contrast and brightness applied */
static void prepare(dither* d, const shz_asset_frame* frame)
{
	const shz_asset_image* in = &frame->inputs[0];
	const int px = (int)frame->controls[C_PIXEL].v[0];
	const float contrast = (float)frame->controls[C_CONTRAST].v[0], brightness = (float)frame->controls[C_BRIGHTNESS].v[0];
	double luma_sum = 0;
	int x, y, k;
	for (y = 0; y < DITHER_H; y++)
	{
		for (x = 0; x < DITHER_W; x++)
		{
			/* the dot this pixel belongs to: its top left pixel */
			const int sx = x - x % px, sy = y - y % px;
			float rgb[3];
			if (in->pixels)
			{
				const uint8_t* s = (const uint8_t*)in->pixels + (size_t)sy * in->stride + (size_t)sx * 4;
				for (k = 0; k < 3; k++)
					rgb[k] = s[k] / 255.0f;
			}
			else
			{
				/* the test pattern: a ramp from left to right, a soft disc in the middle */
				const float fx = (sx + 0.5f) / DITHER_W, fy = (sy + 0.5f) / DITHER_H;
				const float dx = (fx - 0.5f) * 1.78f, dy = fy - 0.5f;
				const float disc = 1.0f - (dx * dx + dy * dy) * 6.0f;
				const float v = fx * 0.6f + (disc > 0 ? disc * 0.4f : 0);
				rgb[0] = rgb[1] = rgb[2] = v;
			}
			luma_sum += luma_of(rgb);
			for (k = 0; k < 3; k++)
				d->work[(y * DITHER_W + x) * 3 + k] = (rgb[k] - 0.5f) * contrast + 0.5f + brightness;
		}
	}
	d->luma = luma_sum / (DITHER_W * DITHER_H);
}

static const uint8_t bayer2[2][2] = { { 0, 2 }, { 3, 1 } };
static const uint8_t bayer4[4][4] = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
static const uint8_t bayer8[8][8] = {
	{ 0, 32, 8, 40, 2, 34, 10, 42 }, { 48, 16, 56, 24, 50, 18, 58, 26 }, { 12, 44, 4, 36, 14, 46, 6, 38 },
	{ 60, 28, 52, 20, 62, 30, 54, 22 }, { 3, 35, 11, 43, 1, 33, 9, 41 }, { 51, 19, 59, 27, 49, 17, 57, 25 },
	{ 15, 47, 7, 39, 13, 45, 5, 37 }, { 63, 31, 55, 23, 61, 29, 53, 21 } };

/* The threshold of the ordered pattern at a dot, -0.5 .. 0.5 */
static float bayer(int method, int dx, int dy)
{
	if (method == M_BAYER2)
		return (bayer2[dy % 2][dx % 2] + 0.5f) / 4.0f - 0.5f;
	if (method == M_BAYER4)
		return (bayer4[dy % 4][dx % 4] + 0.5f) / 16.0f - 0.5f;
	return (bayer8[dy % 8][dx % 8] + 0.5f) / 64.0f - 0.5f;
}

static shz_result dither_update(shz_ctx* ctx, void* instance, const shz_asset_frame* frame)
{
	dither* d = (dither*)instance;
	(void)ctx;
	/* the palette is read here, not only in control_changed: a project restores it without that call */
	if (strcmp(frame->texts[C_PALETTE], d->palette_text) != 0)
	{
		parse_palette(d, frame->texts[C_PALETTE]);
		d->drawn = 0;
	}
	if (frame->inputs[0].changed || memcmp(d->last, frame->controls, sizeof(d->last)) != 0)
		d->drawn = 0;
	frame->values[V_LUMA] = d->luma;
	frame->values[V_DARK] = d->dark;
	return SHZ_OK;
}

static shz_result dither_render(shz_ctx* ctx, void* instance, const shz_asset_frame* frame, shz_asset_image* image)
{
	dither* d = (dither*)instance;
	const int method = (int)frame->controls[C_METHOD].v[0], px = (int)frame->controls[C_PIXEL].v[0];
	const float spread = (float)frame->controls[C_SPREAD].v[0] / (float)(d->colours > 1 ? d->colours - 1 : 1);
	int x, y, k, dark = 0;
	(void)ctx;
	/* no new pixels and no control moved since the last picture: nothing to draw */
	if (d->drawn && !frame->inputs[0].changed)
	{
		image->changed = 0;
		return SHZ_OK;
	}
	prepare(d, frame);
	for (y = 0; y < DITHER_H; y += px)
	{
		for (x = 0; x < DITHER_W; x += px)
		{
			float* w = &d->work[(y * DITHER_W + x) * 3];
			float rgb[3];
			int c, yy, xx;
			if (method == M_FLOYD)
			{
				for (k = 0; k < 3; k++)
					rgb[k] = w[k];
				c = nearest(d, rgb);
				/* the error goes to the dots right and below (7, 3, 5, 1 sixteenths) */
				for (k = 0; k < 3; k++)
				{
					const float err = rgb[k] - d->palette[c][k];
					if (x + px < DITHER_W)
						d->work[(y * DITHER_W + x + px) * 3 + k] += err * 7 / 16;
					if (y + px < DITHER_H)
					{
						if (x >= px)
							d->work[((y + px) * DITHER_W + x - px) * 3 + k] += err * 3 / 16;
						d->work[((y + px) * DITHER_W + x) * 3 + k] += err * 5 / 16;
						if (x + px < DITHER_W)
							d->work[((y + px) * DITHER_W + x + px) * 3 + k] += err * 1 / 16;
					}
				}
			}
			else
			{
				const float t = method == M_THRESHOLD ? 0 : bayer(method, x / px, y / px) * spread;
				for (k = 0; k < 3; k++)
					rgb[k] = w[k] + t;
				c = nearest(d, rgb);
			}
			/* the dot: px x px pixels of colour c */
			for (yy = y; yy < y + px && yy < DITHER_H; yy++)
			{
				uint8_t* row = (uint8_t*)image->pixels + (size_t)yy * image->stride;
				for (xx = x; xx < x + px && xx < DITHER_W; xx++)
				{
					for (k = 0; k < 3; k++)
						row[xx * 4 + k] = (uint8_t)(d->palette[c][k] * 255.0f + 0.5f);
					row[xx * 4 + 3] = 255;
					dark += c == d->darkest;
				}
			}
		}
	}
	d->dark = (double)dark / (DITHER_W * DITHER_H);
	memcpy(d->last, frame->controls, sizeof(d->last));
	d->drawn = 1;
	return SHZ_OK;
}

/* ------------------------------------------------------------------------------------------------- registration */

SHZ_MODULE_ABI("native_dither", "1.0.0", SHZ_FEATURE_TYPES | SHZ_FEATURE_ASSETS | SHZ_FEATURE_ASSET_INPUTS |
	SHZ_FEATURE_ASSET_TEXT)

SHZ_PLUGIN_API shz_result shz_module_register(shz_module* self, const shz_host_api* host_api, const shz_register_api* reg)
{
	shz_asset_def def;
	if (!SHZ_REG_HAS(reg, add_asset))
		return SHZ_ERR_VERSION;
	host = host_api;

	memset(&def, 0, sizeof(def));
	SHZ_INIT(def);
	def.name = "dither";
	def.display_name = "Dither";
	def.doc = "Dithers the picture of its input to a palette of a few colours (Bayer or Floyd-Steinberg), on the CPU";
	def.pixel_format = SHZ_PIXELS_RGBA8;
	def.width = DITHER_W;
	def.height = DITHER_H;
	def.controls = controls;
	def.control_count = C_COUNT;
	def.values = values;
	def.value_count = V_COUNT;
	def.inputs = inputs;
	def.input_count = 1;
	def.create = dither_create;
	def.destroy = dither_destroy;
	def.update = dither_update;
	def.render = dither_render;
	return reg->add_asset(self, "native_dither", &def, NULL);
}
