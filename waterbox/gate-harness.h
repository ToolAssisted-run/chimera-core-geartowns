/* gate-harness.h - the half run-native.c and run-wbx.c share.
 *
 * One run-and-digest loop over the core's exports, so the native reference
 * and the sandboxed core run exactly the same schedule of inputs, and each
 * frame's picture, sound, lag and every memory domain go into the digests
 * both print. The two drivers differ only in how the exports are reached.
 *
 * The wire (waterbox.config "input.buttons"): 0 Power, 1 Reset, 2 Next
 * Floppy Disk, 3 Next CD, 4..16 P1 pad, 17..29 P2 pad, 30 Mouse Left,
 * 31 Mouse Right, then the keyboard. Axes 0 and 1: the mouse's movement.
 */
#ifndef GATE_HARNESS_H
#define GATE_HARNESS_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GATE_PAD1 4
#define GATE_PAD2 17
#define GATE_MOUSE 30
#define GATE_KEYS 32
#define GATE_KEY_COUNT 117
#define GATE_BTN_COUNT (GATE_KEYS + GATE_KEY_COUNT)

struct gate_core
{
	int (*init)(void);
	const char *(*load_error)(void);
	void (*set_button)(int32_t index, int32_t state);
	void (*set_axis)(int32_t index, int32_t value);
	void (*frame)(void);
	const uint32_t *(*video)(int *w, int *h);
	const int16_t *(*audio)(int *n);
	int (*input_was_read)(void);
	int (*domain_count)(void);
	const char *(*domain_name)(int i);
	const uint8_t *(*domain_ptr)(int i);
	int64_t (*domain_size)(int i);
	int (*vsync_numerator)(void);
	int (*vsync_denominator)(void);
	int32_t (*savedata_count)(void);
	const char *(*savedata_name)(int32_t i);
	int64_t (*savedata_size)(int32_t i);
	const uint8_t *(*savedata_buffer)(int32_t i);
	/* optional per-frame hook (the rerecord test); may be NULL */
	void (*pre_frame)(void);
	/* optional: the core's drawing on and off (the turbo test); may be NULL */
	void (*set_rendering)(int on);
};

struct gate_opts
{
	long frames;
	const char *screenshotPath;   /* the last frame, as a .tga */
	int exercise;                 /* drive the pads, mouse and keyboard with a fixed pattern */
	const char *hold;             /* wire indexes held on every frame, comma separated */
	const char *dumpDomain;       /* a memory domain to write after the run... */
	const char *dumpPath;         /* ...into this file */
	const char *savedataDir;      /* write every save-data export here after the run */
	int turbo;                    /* draw nothing for the first half of the run */
	long turboSettle;
	long pressAt;                 /* press one wire index at one frame, for a few frames */
	int pressIndex;
	long digestFrom;              /* the picture and sound digests start at this frame */
	const char *shotsDir;         /* a picture every shotsEvery frames, as <dir>/f<frame>.tga */
	long shotsEvery;
	const char *scriptPath;       /* lines "<first> <last> <wire index>" or "<first> <last> m <dx> <dy>" */
};

/* the --script file: each line holds one wire index over a span of frames,
 * or ("m") moves the mouse by dx, dy counts on each of those frames */
struct gate_span { long from, to; int index, dx, dy; };
static struct gate_span *gate_spans;
static int gate_span_count;

static int gate_load_script(const char *path)
{
	FILE *f = fopen(path, "r");
	if (!f) { perror(path); return 0; }
	char line[256];
	while (fgets(line, sizeof line, f))
	{
		long a, b; int i, dx = 0, dy = 0;
		if (line[0] == '#')
			continue;
		if (sscanf(line, "%ld %ld m %d %d", &a, &b, &dx, &dy) == 4)
			i = -1;
		else if (sscanf(line, "%ld %ld %d", &a, &b, &i) != 3)
			continue;
		gate_spans = (struct gate_span *)realloc(gate_spans, sizeof *gate_spans * (size_t)(gate_span_count + 1));
		gate_spans[gate_span_count].from = a;
		gate_spans[gate_span_count].to = b;
		gate_spans[gate_span_count].index = i;
		gate_spans[gate_span_count].dx = dx;
		gate_spans[gate_span_count].dy = dy;
		gate_span_count++;
	}
	fclose(f);
	return 1;
}

static uint64_t gate_fnv(uint64_t h, const void *p, size_t n)
{
	const uint8_t *b = (const uint8_t *)p;
	if (!h) h = 1469598103934665603ULL;
	for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ULL; }
	return h;
}

/* A fixed pattern, the same in both drivers, so the input path is part of
 * the comparison: P1's pad changes every 8 frames, the mouse moves and
 * clicks, and a key goes down and up every 24 frames. Power and Reset are
 * never pressed. */
static void gate_exercise(long frame, uint8_t *buttons, int32_t *axes)
{
	uint64_t x = (uint64_t)(frame / 8) * 6364136223846793005ULL + 1442695040888963407ULL;
	x ^= x >> 33;
	for (int k = 0; k < 13; k++)
		buttons[GATE_PAD1 + k] = (x >> k) & 1;
	/* up with down, or left with right, is SELECT or RUN on this pad;
	 * keep the pattern to directions a stick makes */
	if (buttons[GATE_PAD1 + 0] && buttons[GATE_PAD1 + 1]) buttons[GATE_PAD1 + 1] = 0;
	if (buttons[GATE_PAD1 + 2] && buttons[GATE_PAD1 + 3]) buttons[GATE_PAD1 + 3] = 0;

	uint64_t w = (uint64_t)frame * 2862933555777941757ULL + 3037000493ULL;
	w ^= w >> 29;
	axes[0] = (int32_t)(w % 9) - 4;
	axes[1] = (int32_t)((w >> 8) % 9) - 4;
	buttons[GATE_MOUSE + 0] = (frame / 20) % 3 == 1;
	buttons[GATE_MOUSE + 1] = (frame / 30) % 4 == 2;

	long k = frame / 24;
	if (frame % 24 < 6)
		buttons[GATE_KEYS + (int)(k * 7 % GATE_KEY_COUNT)] = 1;
}

static int gate_write_tga(const char *path, const uint32_t *bgra, int w, int h)
{
	FILE *f = fopen(path, "wb");
	if (!f) return 0;
	uint8_t hdr[18] = { 0 };
	hdr[2] = 2;
	hdr[12] = w & 0xff; hdr[13] = (w >> 8) & 0xff;
	hdr[14] = h & 0xff; hdr[15] = (h >> 8) & 0xff;
	hdr[16] = 32;
	hdr[17] = 0x20;
	fwrite(hdr, 1, 18, f);
	fwrite(bgra, 4, (size_t)w * h, f);
	fclose(f);
	return 1;
}

static int gate_run(const struct gate_core *c, const struct gate_opts *o)
{
	if (c->init() != 1)
	{
		fprintf(stderr, "Init failed: %s\n", c->load_error ? c->load_error() : "?");
		return 1;
	}

	uint8_t held[GATE_BTN_COUNT];
	memset(held, 0, sizeof held);
	if (o->hold)
	{
		const char *s = o->hold;
		while (*s)
		{
			long i = strtol(s, (char **)&s, 10);
			if (i >= 0 && i < GATE_BTN_COUNT) held[i] = 1;
			if (*s == ',') s++;
			else if (*s) { fprintf(stderr, "bad --hold list\n"); return 1; }
		}
	}

	if (o->scriptPath && !gate_load_script(o->scriptPath))
		return 1;

	const long frames = o->frames;
	const long tail = frames / 2;
	const long hashFrom = tail + o->turboSettle;
	uint64_t vh = 0, th = 0, ah = 0;
	long lag = 0, samples = 0, nonzero = 0;
	uint8_t buttons[GATE_BTN_COUNT], prev[GATE_BTN_COUNT];
	int32_t axes[2] = { 0, 0 }, prevAxes[2] = { 0, 0 };
	memset(prev, 0, sizeof prev);

	for (long f = 0; f < frames; f++)
	{
		memcpy(buttons, held, sizeof buttons);
		axes[0] = axes[1] = 0;
		if (o->exercise)
			gate_exercise(f, buttons, axes);
		if (o->pressIndex >= 0 && f >= o->pressAt && f < o->pressAt + 4)
			buttons[o->pressIndex] = 1;
		for (int s = 0; s < gate_span_count; s++)
		{
			if (f < gate_spans[s].from || f > gate_spans[s].to)
				continue;
			if (gate_spans[s].index >= 0 && gate_spans[s].index < GATE_BTN_COUNT)
				buttons[gate_spans[s].index] = 1;
			else if (gate_spans[s].index < 0)
			{
				axes[0] += gate_spans[s].dx;
				axes[1] += gate_spans[s].dy;
			}
		}

		if (o->turbo && c->set_rendering)
			c->set_rendering(f >= tail);
		if (c->pre_frame)
			c->pre_frame();

		for (int i = 0; i < GATE_BTN_COUNT; i++)
		{
			if (buttons[i] != prev[i])
				c->set_button(i, buttons[i]);
			prev[i] = buttons[i];
		}
		for (int i = 0; i < 2; i++)
		{
			if (axes[i] != prevAxes[i] && c->set_axis)
				c->set_axis(i, axes[i]);
			prevAxes[i] = axes[i];
		}

		c->frame();

		int w = 0, h = 0, n = 0;
		const uint32_t *video = c->video(&w, &h);
		const int16_t *audio = c->audio(&n);
		samples += n;
		for (int i = 0; i < n * 2; i++)
			nonzero += audio[i] != 0;
		if (f >= o->digestFrom)
		{
			vh = gate_fnv(vh, &w, sizeof w);
			vh = gate_fnv(vh, &h, sizeof h);
			vh = gate_fnv(vh, video, (size_t)w * h * 4);
			ah = gate_fnv(ah, audio, (size_t)n * 2 * sizeof(int16_t));
		}
		if (f >= hashFrom)
		{
			th = gate_fnv(th, &w, sizeof w);
			th = gate_fnv(th, &h, sizeof h);
			th = gate_fnv(th, video, (size_t)w * h * 4);
		}
		if (!c->input_was_read())
			lag++;

		if (o->shotsDir && o->shotsEvery > 0 && (f + 1) % o->shotsEvery == 0)
		{
			char path[4096];
			snprintf(path, sizeof path, "%s/f%06ld.tga", o->shotsDir, f + 1);
			gate_write_tga(path, video, w, h);
		}
		if (o->screenshotPath && f == frames - 1)
			gate_write_tga(o->screenshotPath, video, w, h);
		if (f == frames - 1)
			printf("size=%dx%d\n", w, h);
	}

	printf("frames=%ld\n", frames);
	printf("vsync=%d/%d\n", c->vsync_numerator(), c->vsync_denominator());
	printf("videoHash=%016llx\n", (unsigned long long)vh);
	printf("tailVideoHash=%016llx\n", (unsigned long long)th);
	printf("audioHash=%016llx\n", (unsigned long long)ah);
	printf("audioSamples=%ld\n", samples);
	printf("audioNonzero=%ld\n", nonzero);
	printf("lagFrames=%ld\n", lag);
	int nd = c->domain_count();
	for (int i = 0; i < nd; i++)
	{
		uint64_t dh = gate_fnv(0, c->domain_ptr(i), (size_t)c->domain_size(i));
		printf("domain[%s]=%016llx\n", c->domain_name(i), (unsigned long long)dh);
	}
	if (o->savedataDir)
	{
		int32_t count = c->savedata_count();
		printf("savedataFiles=%d\n", count);
		for (int32_t i = 0; i < count; i++)
		{
			char path[4096];
			snprintf(path, sizeof path, "%s/%s", o->savedataDir, c->savedata_name(i));
			FILE *f = fopen(path, "wb");
			if (!f) { perror(path); return 1; }
			fwrite(c->savedata_buffer(i), 1, (size_t)c->savedata_size(i), f);
			fclose(f);
		}
	}
	if (o->dumpDomain && o->dumpPath)
	{
		int found = 0;
		for (int i = 0; i < nd; i++)
		{
			if (strcmp(c->domain_name(i), o->dumpDomain) != 0)
				continue;
			FILE *f = fopen(o->dumpPath, "wb");
			if (!f) { perror(o->dumpPath); return 1; }
			fwrite(c->domain_ptr(i), 1, (size_t)c->domain_size(i), f);
			fclose(f);
			found = 1;
			break;
		}
		if (!found)
		{
			fprintf(stderr, "no such domain to dump: %s\n", o->dumpDomain);
			return 1;
		}
	}
	return 0;
}

static int gate_parse_opts(int argc, char **argv, int first, struct gate_opts *o)
{
	memset(o, 0, sizeof *o);
	o->frames = 600;
	o->pressIndex = -1;
	for (int i = first; i < argc; i++)
	{
		if (!strcmp(argv[i], "--frames") && i + 1 < argc) o->frames = strtol(argv[++i], 0, 0);
		else if (!strcmp(argv[i], "--screenshot") && i + 1 < argc) o->screenshotPath = argv[++i];
		else if (!strcmp(argv[i], "--exercise")) o->exercise = 1;
		else if (!strcmp(argv[i], "--hold") && i + 1 < argc) o->hold = argv[++i];
		else if (!strcmp(argv[i], "--press") && i + 2 < argc) { o->pressIndex = (int)strtol(argv[++i], 0, 0); o->pressAt = strtol(argv[++i], 0, 0); }
		else if (!strcmp(argv[i], "--digest-from") && i + 1 < argc) o->digestFrom = strtol(argv[++i], 0, 0);
		else if (!strcmp(argv[i], "--dump-domain") && i + 2 < argc) { o->dumpDomain = argv[++i]; o->dumpPath = argv[++i]; }
		else if (!strcmp(argv[i], "--savedata-out") && i + 1 < argc) o->savedataDir = argv[++i];
		else if (!strcmp(argv[i], "--shots") && i + 2 < argc) { o->shotsDir = argv[++i]; o->shotsEvery = strtol(argv[++i], 0, 0); }
		else if (!strcmp(argv[i], "--script") && i + 1 < argc) o->scriptPath = argv[++i];
		else if (!strcmp(argv[i], "--turbo")) o->turbo = 1;
		else if (!strcmp(argv[i], "--turbo-settle") && i + 1 < argc) o->turboSettle = strtol(argv[++i], 0, 0);
		else if (!strcmp(argv[i], "--rerecord")) ; /* run-wbx's */
		else { fprintf(stderr, "unknown argument %s\n", argv[i]); return 0; }
	}
	return 1;
}

#endif /* GATE_HARNESS_H */
