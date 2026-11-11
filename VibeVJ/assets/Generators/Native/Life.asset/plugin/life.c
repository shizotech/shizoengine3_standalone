/*
 * Life: a native VibeVJ asset in plain C (issue #201), built only against shz_abi.h.
 *
 * Conway's Game of Life (and three other rules) on a field of 192 x 108 cells, computed on the CPU. The engine shows
 * it like a shader: the picture is the field (living cells in one colour, dead ones glowing out in another), and three
 * value outputs (how full the field is, how many cells were born, a pulse at every generation) can be linked into
 * other generators. The controls are declared below with the same kinds a shader declares with its //@ annotations;
 * VibeVJ builds the same UI from them, and links, MIDI mappings, projects and presets work like for a shader.
 *
 * The walkthrough is the section "A native VibeVJ asset" of core/shizoscript3_core_cabi/README.md.
 *
 * Build (Linux):  gcc -std=c99 -O2 -fPIC -shared -fvisibility=hidden -I<repo>/core/shizoscript3_core_cabi/include \
 *                     life.c -o native/linux_x64/shzmodule_native_life.so -lm
 * or CMakeLists.txt next to this file (Linux, macOS, Windows). _testing/linux_app/build.sh, shzscript_macos/CMakeLists.txt
 * and modules/shzmodule_native_life/shzmodule_native_life.vcxproj build it in this repository.
 */

#include "shz_abi.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define LIFE_W 192
#define LIFE_H 108

static const shz_host_api* host = NULL;

/* ------------------------------------------------------------------------------------------- controls and values */

/* The order of the controls: frame->controls[C_RATE] is the value of "rate", ... */
enum { C_RATE, C_SYNC, C_RULE, C_DENSITY, C_SPARKS, C_RESEED, C_WRAP, C_FADE, C_ALIVE, C_DEAD, C_COUNT };
enum { V_POPULATION, V_BIRTHS, V_STEP, V_COUNT };

/* The rules of the enum "rule": birth / survival as bit masks of the number of living neighbours */
static const unsigned rule_birth[] = { 1u << 3, (1u << 3) | (1u << 6), 1u << 2,
	(1u << 3) | (1u << 6) | (1u << 7) | (1u << 8) };
static const unsigned rule_survive[] = { (1u << 2) | (1u << 3), (1u << 2) | (1u << 3), 0,
	(1u << 3) | (1u << 4) | (1u << 6) | (1u << 7) | (1u << 8) };

/* A control: kind, name, display name (NULL: from the name), tooltip, min, max, start value (per component) */
#define CONTROL(kind_, name_, display_, doc_, min_, max_, ...) \
	{ sizeof(shz_control_def), kind_, name_, display_, doc_, { min_, min_, min_, min_ }, { max_, max_, max_, max_ }, \
		{ __VA_ARGS__ }, NULL, 0, 0, NULL, 0, 0 }

static const shz_control_def controls[C_COUNT] = {
	CONTROL(SHZ_CONTROL_SLIDER, "rate", NULL, "Generations per second (when Sync is off)", 0, 30, 8),
	CONTROL(SHZ_CONTROL_BUTTON, "sync", NULL, "One generation on every beat of the timeline instead of Rate", 0, 0, 0),
	{ sizeof(shz_control_def), SHZ_CONTROL_ENUM, "rule", NULL, "Which cells are born and which live on", { 0 }, { 0 }, { 0 },
		"Conway,HighLife,Seeds,Day & Night", 0, 0, NULL, 0, 0 },
	CONTROL(SHZ_CONTROL_SLIDER, "density", NULL, "How full a new field is (Reseed)", 0, 1, 0.3),
	CONTROL(SHZ_CONTROL_SLIDER, "sparks", NULL, "New cells thrown in at random every generation, so the field never dies out",
		0, 0.01, 0.0005),
	CONTROL(SHZ_CONTROL_PUSHBUTTON, "reseed", NULL, "Fills the field anew, every press", 0, 0, 0),
	CONTROL(SHZ_CONTROL_BUTTON, "wrap", NULL, "The edges wrap around (a torus); off: outside is dead", 0, 0, 1),
	CONTROL(SHZ_CONTROL_SLIDER, "fade", NULL, "How long dead cells glow on: 0 none, 1 for ever", 0, 1, 0.85),
	CONTROL(SHZ_CONTROL_RGB, "alive", "Alive colour", "The colour of living cells", 0, 0, 1.0, 0.75, 0.2),
	CONTROL(SHZ_CONTROL_RGB, "dead", "Dead colour", "The colour of the empty field", 0, 0, 0.02, 0.02, 0.06),
};

static const shz_asset_value_def values[V_COUNT] = {
	{ sizeof(shz_asset_value_def), 0, "population", NULL, "The share of living cells, 0 to 1", 0, 1 },
	{ sizeof(shz_asset_value_def), 0, "births", NULL, "The share of cells born in the last generation", 0, 0.2 },
	{ sizeof(shz_asset_value_def), 0, "step", NULL, "1 in the frame a generation happened, else 0", 0, 1 },
};

/* ------------------------------------------------------------------------------------------------ the instance */

typedef struct life
{
	uint8_t cells[LIFE_W * LIFE_H]; /* 1 = alive */
	uint8_t next[LIFE_W * LIFE_H];
	float glow[LIFE_W * LIFE_H];    /* 1 while alive, fades after */
	double pending;                 /* generations owed by Rate (fraction) */
	double last_beat;
	uint64_t generation;
	uint32_t rng;
	int dirty;                      /* the cells changed: the picture has to be drawn again */
	double drawn_colours[6];        /* the colours of the last picture (a new colour draws again) */
} life;

static uint32_t life_random(life* l)
{
	/* xorshift32 */
	uint32_t x = l->rng;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	l->rng = x;
	return x;
}

static double life_random01(life* l)
{
	return (life_random(l) >> 8) / 16777216.0;
}

static void life_seed(life* l, double density)
{
	int i;
	for (i = 0; i < LIFE_W * LIFE_H; i++)
	{
		l->cells[i] = life_random01(l) < density ? 1 : 0;
		l->glow[i] = l->cells[i] ? 1.0f : 0.0f;
	}
	l->generation = 0;
	l->dirty = 1;
}

/* One generation; returns the number of cells born */
static int life_step(life* l, const shz_control_value* c)
{
	const int rule = (int)c[C_RULE].v[0];
	const unsigned birth = rule_birth[rule], survive = rule_survive[rule];
	const int wrap = c[C_WRAP].v[0] != 0;
	const float fade = (float)c[C_FADE].v[0];
	const double sparks = c[C_SPARKS].v[0];
	int x, y, born = 0;
	for (y = 0; y < LIFE_H; y++)
	{
		for (x = 0; x < LIFE_W; x++)
		{
			int n = 0, dx, dy;
			for (dy = -1; dy <= 1; dy++)
			{
				for (dx = -1; dx <= 1; dx++)
				{
					int nx = x + dx, ny = y + dy;
					if (dx == 0 && dy == 0)
						continue;
					if (wrap)
					{
						nx = (nx + LIFE_W) % LIFE_W;
						ny = (ny + LIFE_H) % LIFE_H;
					}
					else if (nx < 0 || ny < 0 || nx >= LIFE_W || ny >= LIFE_H)
						continue;
					n += l->cells[ny * LIFE_W + nx];
				}
			}
			{
				const int i = y * LIFE_W + x;
				const int alive = l->cells[i] ? (survive >> n) & 1u : (birth >> n) & 1u;
				l->next[i] = (uint8_t)alive;
				if (alive && !l->cells[i])
					born++;
			}
		}
	}
	for (x = 0; x < LIFE_W * LIFE_H; x++)
	{
		if (!l->next[x] && sparks > 0 && life_random01(l) < sparks)
		{
			l->next[x] = 1;
			born++;
		}
		l->cells[x] = l->next[x];
		l->glow[x] = l->cells[x] ? 1.0f : l->glow[x] * fade;
	}
	l->generation++;
	l->dirty = 1;
	return born;
}

/* ------------------------------------------------------------------------------------------------- the callbacks */

static shz_result life_create(shz_ctx* ctx, const shz_asset_frame* frame, void** instance_out)
{
	life* l = (life*)calloc(1, sizeof(life));
	if (!l)
		return host->error(ctx, SHZ_ERR_NOMEM, "no memory for the field");
	l->rng = 0x9E3779B9u ^ (uint32_t)(size_t)l;
	if (!l->rng)
		l->rng = 1;
	life_seed(l, frame->controls[C_DENSITY].v[0]);
	*instance_out = l;
	return SHZ_OK;
}

static void life_destroy(void* instance, void* asset_user)
{
	(void)asset_user;
	free(instance);
}

static shz_result life_update(shz_ctx* ctx, void* instance, const shz_asset_frame* frame)
{
	life* l = (life*)instance;
	const shz_control_value* c = frame->controls;
	int steps = 0, born = 0, i, alive = 0;
	(void)ctx;
	if (c[C_SYNC].v[0] != 0)
	{
		/* a generation for every beat the timeline passed (none when it jumped back) */
		if (frame->beat > l->last_beat)
			steps = (int)(floor(frame->beat) - floor(l->last_beat));
		l->last_beat = frame->beat;
	}
	else
	{
		l->pending += frame->dt * c[C_RATE].v[0];
		steps = (int)l->pending;
		l->pending -= steps;
		l->last_beat = frame->beat;
	}
	if (steps > 8)
		steps = 8; /* after a stall: do not try to catch up */
	for (i = 0; i < steps; i++)
		born = life_step(l, c);
	for (i = 0; i < LIFE_W * LIFE_H; i++)
		alive += l->cells[i];
	frame->values[V_POPULATION] = (double)alive / (LIFE_W * LIFE_H);
	if (steps > 0)
		frame->values[V_BIRTHS] = (double)born / (LIFE_W * LIFE_H);
	frame->values[V_STEP] = steps > 0 ? 1.0 : 0.0;
	return SHZ_OK;
}

static uint8_t to_byte(double v)
{
	return (uint8_t)(v <= 0 ? 0 : v >= 1 ? 255 : v * 255.0 + 0.5);
}

static shz_result life_render(shz_ctx* ctx, void* instance, const shz_asset_frame* frame, shz_asset_image* image)
{
	life* l = (life*)instance;
	const double* on = frame->controls[C_ALIVE].v;
	const double* off = frame->controls[C_DEAD].v;
	uint32_t x, y;
	int i;
	(void)ctx;
	/* the colours are read here, not only in control_changed: a project that is loaded sets them without it */
	for (i = 0; i < 3; i++)
	{
		if (l->drawn_colours[i] != on[i] || l->drawn_colours[3 + i] != off[i])
			l->dirty = 1;
		l->drawn_colours[i] = on[i];
		l->drawn_colours[3 + i] = off[i];
	}
	if (!l->dirty)
	{
		image->changed = 0; /* the same picture: the engine skips the upload */
		return SHZ_OK;
	}
	/* the size is LIFE_W x LIFE_H (no SHZ_ASSET_FOLLOW_SIZE), one pixel per cell */
	for (y = 0; y < image->height; y++)
	{
		uint8_t* row = (uint8_t*)image->pixels + y * image->stride;
		for (x = 0; x < image->width; x++)
		{
			const double g = l->glow[y * LIFE_W + x];
			row[x * 4 + 0] = to_byte(off[0] + (on[0] - off[0]) * g);
			row[x * 4 + 1] = to_byte(off[1] + (on[1] - off[1]) * g);
			row[x * 4 + 2] = to_byte(off[2] + (on[2] - off[2]) * g);
			row[x * 4 + 3] = 255;
		}
	}
	l->dirty = 0;
	return SHZ_OK;
}

static shz_result life_control_changed(shz_ctx* ctx, void* instance, uint32_t index, const shz_asset_frame* frame)
{
	life* l = (life*)instance;
	(void)ctx;
	/* an action: every press of Reseed (not called when a project restores the button) */
	if (index == C_RESEED)
		life_seed(l, frame->controls[C_DENSITY].v[0]);
	return SHZ_OK;
}

/* The field is the state beyond the controls: saved with the project / a preset as [generation, cells (bytes)] */
static shz_result life_save(shz_ctx* ctx, void* self, shz_value* out)
{
	life* l = (life*)self;
	shz_value cells, gen = shz_int((int64_t)l->generation);
	shz_result r = host->make_map(ctx, out);
	if (r != SHZ_OK)
		return r;
	r = host->make_bytes(ctx, l->cells, sizeof(l->cells), &cells);
	if (r != SHZ_OK)
		return r;
	host->map_set(ctx, out, "cells", &cells);
	host->map_set(ctx, out, "generation", &gen);
	return SHZ_OK;
}

static shz_result life_load(shz_ctx* ctx, void* self, const shz_value* data)
{
	life* l = (life*)self;
	shz_value cells, gen;
	shz_buffer_view view;
	int i;
	if (host->map_get(ctx, data, "cells", &cells) != SHZ_OK || cells.type != SHZ_T_BYTES)
		return SHZ_OK; /* nothing saved (an older project): keep the field */
	memset(&view, 0, sizeof(view));
	SHZ_INIT(view);
	if (host->bytes_lock(ctx, &cells, SHZ_LOCK_READ, &view) != SHZ_OK)
		return SHZ_OK;
	if (view.size == sizeof(l->cells))
	{
		for (i = 0; i < LIFE_W * LIFE_H; i++)
		{
			l->cells[i] = view.data[i] ? 1 : 0;
			l->glow[i] = l->cells[i] ? 1.0f : 0.0f;
		}
		l->dirty = 1;
	}
	host->bytes_unlock(ctx, &view);
	if (host->map_get(ctx, data, "generation", &gen) == SHZ_OK && shz_is_number(&gen))
		l->generation = (uint64_t)shz_to_int(&gen);
	return SHZ_OK;
}

/* ------------------------------------------------------------------------------------------------- registration */

SHZ_MODULE_ABI("native_life", "1.0.0", SHZ_FEATURE_TYPES | SHZ_FEATURE_BUFFERS | SHZ_FEATURE_ASSETS)

SHZ_PLUGIN_API shz_result shz_module_register(shz_module* self, const shz_host_api* host_api, const shz_register_api* reg)
{
	shz_asset_def def;
	if (!SHZ_REG_HAS(reg, add_asset))
		return SHZ_ERR_VERSION;
	host = host_api;

	memset(&def, 0, sizeof(def));
	SHZ_INIT(def);
	def.name = "life";
	def.display_name = "Life";
	def.doc = "Conway's Game of Life and three other rules on a field of 192 x 108 cells, computed on the CPU";
	def.pixel_format = SHZ_PIXELS_RGBA8;
	def.width = LIFE_W;
	def.height = LIFE_H;
	def.controls = controls;
	def.control_count = C_COUNT;
	def.values = values;
	def.value_count = V_COUNT;
	def.create = life_create;
	def.destroy = life_destroy;
	def.update = life_update;
	def.render = life_render;
	def.control_changed = life_control_changed;
	def.save = life_save;
	def.load = life_load;
	return reg->add_asset(self, "native_life", &def, NULL);
}
