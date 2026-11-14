/* cinterface.cpp - Geartowns behind Chimera's guest interface.
 *
 * Geartowns' libretro core (platforms/libretro/libretro.cpp) is the model:
 * the same calls in the same order to boot a machine, read its controls and
 * take its picture and sound. What a frontend does there with folders - the
 * firmware search, working copies of disks, a shared CMOS file - is done
 * here with the files Chimera mounts by name, and everything a game writes
 * stays in the machine's memory, so a savestate holds it.
 *
 * This file compiles the same for the guest (miniBox's emulibc) and for the
 * native reference build (native-shim/emulibc.h): the test script compares
 * the two.
 */
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <vector>

#include <emulibc.h>
#include <waterbox_settings.h>
#include <waterbox_slots.h>

#include "geartowns.h"
#include "drive/floppy_image.h"
#include "drive/floppy_disk.h"
#include "drive/fdc.h"
#include "drive/memory_card.h"
#include "input/keyboard.h"
#include "system/msm58321.h"
#include "libretro.h"

#include "keys.h"

/* A text a person reads is a key of languages/en.json, each of its
 * arguments after a TEXT_ARG (Chimera docs/translations.md). */
#define TEXT_ARG "\x1f"

/* ---- upstream's log, under __LIBRETRO__: one line on stderr ---- */
static void chimera_log(enum retro_log_level level, const char *fmt, ...)
{
	(void)level;
	va_list va;
	va_start(va, fmt);
	fputs("[geartowns] ", stderr);
	vfprintf(stderr, fmt, va);
	va_end(va);
}
retro_log_printf_t log_cb = chimera_log;

/* the read of the controls, from patches/0001 (io.cpp) */
extern void (*g_gt_input_read_hook)(void);

/* ---- the wire: waterbox.config "input.buttons", in this order ----
 *   0 Power, 1 Reset, 2 Next Floppy Disk, 3 Next CD
 *   4.. P1 pad, 13 buttons; then P2 pad, 13 buttons
 *   Mouse Left, Mouse Right
 *   the keyboard, in keys.h's order
 * Axes: 0 Mouse X, 1 Mouse Y (movement this frame, in counts). */
#define BTN_POWER 0
#define BTN_RESET 1
#define BTN_NEXT_FLOPPY 2
#define BTN_NEXT_CD 3
#define BTN_PAD 4
#define PAD_BUTTONS 13
#define BTN_MOUSE (BTN_PAD + 2 * PAD_BUTTONS)
#define BTN_KEYS (BTN_MOUSE + 2)
#define BTN_COUNT (BTN_KEYS + KEY_COUNT)
#define AXIS_COUNT 2

static const u16 k_pad_bits[PAD_BUTTONS] = {
	GT_GAMEPAD_UP, GT_GAMEPAD_DOWN, GT_GAMEPAD_LEFT, GT_GAMEPAD_RIGHT,
	GT_GAMEPAD_SELECT, GT_GAMEPAD_RUN, GT_GAMEPAD_A, GT_GAMEPAD_B,
	GT_GAMEPAD_C, GT_GAMEPAD_X, GT_GAMEPAD_Y, GT_GAMEPAD_Z, GT_GAMEPAD_ZOOM,
};

static const GT_Keys k_keys[KEY_COUNT] = {
#define KEY(label, code, mnemonic, header, bind) code,
	KEY_LIST
#undef KEY
};

/* The machine's state that lives here and not in Geartowns: what is held,
 * what was held last frame (so a key is pressed once), which disk is in. A
 * savestate carries all of it, as it carries the emulator. */
static uint8_t g_buttons[BTN_COUNT];
static uint8_t g_held[BTN_COUNT];
static int32_t g_axes[AXIS_COUNT];
static int g_inputRead;
static int g_inited;
static char g_loadError[512];

static GeartownsCore *g_core;
static u8 *g_frame;
static uint32_t *g_video;
static int g_vwidth = 640, g_vheight = 480;
static s16 g_audio[GT_AUDIO_BUFFER_SIZE];
static int g_audioFrames;
/* the frame rate of the mode the machine is in, in millionths of a hertz */
static int32_t g_vsyncNum = 60000000;

/* Turbo: the frontend's choice for the moment, not the machine's. */
ECL_INVISIBLE static int g_render = 1;

/* the controllers on the two game ports */
static GT_Controller_Type g_port[GT_MAX_GAMEPADS];

/* the project's disks, in slot order, and which is in each drive */
static std::vector<std::string> g_floppies;
static std::vector<std::string> g_cds;
static int g_floppyIn = -1;
static int g_cdIn = -1;

/* ---------------------------------------------------------------- settings */

static const char *const k_models[GT_MACHINE_COUNT] = {
	"model1_2", "1f_2f", "10f_20f", "cx", "ux", "ug", "hg", "hr", "ur",
	"me", "ma", "mx", "mf_fresh", "hc", "marty",
};

static int setting_choice(const char *name, const char *const *values, int count, int dflt)
{
	char buf[64];
	buf[0] = 0;
	if (wbx_setting_str(name, buf, sizeof buf) <= 0)
		return dflt;
	for (int i = 0; i < count; i++)
		if (values[i] && strcmp(buf, values[i]) == 0)
			return i;
	fprintf(stderr, "[geartowns] unknown %s '%s', using the default\n", name, buf);
	return dflt;
}

/* auto, or a whole number */
static int setting_auto_int(const char *name)
{
	char buf[64];
	buf[0] = 0;
	if (wbx_setting_str(name, buf, sizeof buf) <= 0 || strcmp(buf, "auto") == 0)
		return GT_MACHINE_AUTO;
	return atoi(buf);
}

static int setting_auto_bool(const char *name)
{
	char buf[16];
	buf[0] = 0;
	if (wbx_setting_str(name, buf, sizeof buf) <= 0 || strcmp(buf, "auto") == 0)
		return GT_MACHINE_AUTO;
	return strcmp(buf, "on") == 0 ? 1 : 0;
}

static GT_Controller_Type port_device(const char *name, GT_Controller_Type automatic)
{
	static const char *const values[] = { "auto", "none", "pad", "pad6", "martyPad", "mouse" };
	switch (setting_choice(name, values, 6, 0))
	{
	case 1: return GT_CONTROLLER_NONE;
	case 2: return GT_CONTROLLER_ORIGINAL_GAMEPAD;
	case 3: return GT_CONTROLLER_6_BUTTON_GAMEPAD;
	case 4: return GT_CONTROLLER_MARTY_GAMEPAD;
	case 5: return GT_CONTROLLER_MOUSE;
	default: return automatic;
	}
}

/* The machine's clock starts at the project's second: the sandbox's clock
 * reads it. The native reference has the host's clock, so it takes the
 * sandbox's default start, 2017-05-27 12:44:28 UTC, as the two must be the
 * same machine. */
static s64 clock_start(void)
{
#ifdef CHIMERA_GUEST
	return (s64)time(NULL);
#else
	return 1495889068;
#endif
}

/* ---------------------------------------------------------------- files */

static bool read_file(const char *name, std::vector<u8> &out)
{
	FILE *f = fopen(name, "rb");
	if (!f)
		return false;
	fseek(f, 0, SEEK_END);
	long size = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (size < 0)
	{
		fclose(f);
		return false;
	}
	out.resize((size_t)size);
	bool ok = size == 0 || fread(out.data(), 1, (size_t)size, f) == (size_t)size;
	fclose(f);
	return ok;
}

static void slot_files(const char *slot, std::vector<std::string> &out)
{
	int n = wbx_slot_count(slot);
	for (int i = 0; i < n; i++)
	{
		char name[1024];
		if (wbx_slot_name(slot, i, name, sizeof name))
			out.push_back(name);
	}
}

static bool insert_floppy(int index, int drive)
{
	std::vector<u8> data;
	const char *name = g_floppies[(size_t)index].c_str();
	if (!read_file(name, data))
		return false;
	u32 offset = 0, size = 0;
	if (!FloppyImage::GetDisk(data.data(), (u32)data.size(), 0, &offset, &size))
		return false;
	if (!g_core->InsertFloppy(drive, data.data() + offset, size, false, 0, 0, data.data() + offset, size))
		return false;
	fprintf(stderr, "[geartowns] floppy %d: %s\n", drive + 1, name);
	return true;
}

static bool insert_cd(int index)
{
	const char *name = g_cds[(size_t)index].c_str();
	if (!g_core->LoadMedia(name))
		return false;
	fprintf(stderr, "[geartowns] CD: %s\n", name);
	return true;
}

/* ---------------------------------------------------------------- input */

static void apply_input(void)
{
	Input *input = g_core->GetInput();
	for (int port = 0; port < GT_MAX_GAMEPADS; port++)
	{
		GT_GamePad_State state = { 0 };
		if (g_port[port] == GT_CONTROLLER_MOUSE)
		{
			input->SetMouseDelta(port, g_axes[0], g_axes[1]);
			if (g_buttons[BTN_MOUSE + 0])
				state.buttons |= GT_GAMEPAD_A;
			if (g_buttons[BTN_MOUSE + 1])
				state.buttons |= GT_GAMEPAD_B;
		}
		else if (g_port[port] != GT_CONTROLLER_NONE)
		{
			const uint8_t *b = &g_buttons[BTN_PAD + port * PAD_BUTTONS];
			for (int i = 0; i < PAD_BUTTONS; i++)
				if (b[i])
					state.buttons |= k_pad_bits[i];
		}
		input->SetGamePadState(port, state);
	}

	/* the keyboard sends a make code when a key goes down and a break code
	 * when it comes up, so it is told of changes */
	for (int k = 0; k < KEY_COUNT; k++)
	{
		const int i = BTN_KEYS + k;
		if (g_buttons[i] && !g_held[i])
			g_core->KeyPressed(k_keys[k]);
		else if (!g_buttons[i] && g_held[i])
			g_core->KeyReleased(k_keys[k]);
	}
}

/* ---------------------------------------------------------------- exports */

extern "C" {

ECL_EXPORT const char *GetLoadError(void)
{
	return g_loadError;
}

/* Chimera's function for each read of the controls (chimera#344). The same
 * callback slot in every session; no savestate carries it. */
ECL_INVISIBLE static uintptr_t (*g_inputPoll)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t);
ECL_EXPORT void SetInputPollCallback(uint64_t fn)
{
	g_inputPoll = (uintptr_t (*)(uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t))(uintptr_t)fn;
}

static void on_input_read(void)
{
	g_inputRead = 1;
	if (g_inputPoll)
		g_inputPoll(0, 0, 0, 0, 0, 0);
}

ECL_EXPORT int Init(void)
{
	g_loadError[0] = 0;

	const int model = setting_choice("model", k_models, GT_MACHINE_COUNT, GT_MACHINE_MODEL1_2);
	if (!k_machine_profiles[model].emulated)
	{
		snprintf(g_loadError, sizeof g_loadError, "error.model_not_emulated");
		return 0;
	}

	g_core = new GeartownsCore();
	g_core->Init();
	g_core->LockRAMSize(true);

	/* The firmware is mounted by the names Geartowns looks for (FMT_SYS.ROM
	 * and the rest); "." is the folder of mounted files (patches/0001). The
	 * chosen model's set is used as it is, whatever its checksums say. */
	g_core->SetModelFirmwareFolder((GT_Machine_Model)model, ".");

	static const char *const speed[] = { "auto", "off", "on" };
	GT_Machine_Settings ms;
	ms.model = model;
	ms.cpu_mhz = setting_auto_int("cpuMhz");
	ms.ram_mb = setting_auto_int("ramMb");
	ms.fpu = setting_auto_bool("fpu");
	int sm = setting_choice("speedMode", speed, 3, 0);
	ms.speed_mode = sm == 0 ? GT_MACHINE_AUTO : sm == 2 ? 1 : 0;
	g_core->SetMachineSettings(ms);

	g_frame = new u8[GT_MAX_FRAME_BUFFER_WIDTH * GT_MAX_FRAME_BUFFER_HEIGHT * 4];
	memset(g_frame, 0, GT_MAX_FRAME_BUFFER_WIDTH * GT_MAX_FRAME_BUFFER_HEIGHT * 4);
	g_video = new uint32_t[GT_MAX_FRAME_BUFFER_WIDTH * GT_MAX_FRAME_BUFFER_HEIGHT];
	memset(g_video, 0, GT_MAX_FRAME_BUFFER_WIDTH * GT_MAX_FRAME_BUFFER_HEIGHT * 4);

	/* the media: the first disk of each kind goes in at power on */
	slot_files("floppy", g_floppies);
	slot_files("cdrom", g_cds);
	if (!g_floppies.empty())
	{
		if (!insert_floppy(0, 0))
		{
			snprintf(g_loadError, sizeof g_loadError, "error.floppy_rejected" TEXT_ARG "%s", g_floppies[0].c_str());
			return 0;
		}
		g_floppyIn = 0;
	}
	if (!g_cds.empty())
	{
		if (!insert_cd(0))
		{
			snprintf(g_loadError, sizeof g_loadError, "error.cd_rejected" TEXT_ARG "%s", g_cds[0].c_str());
			return 0;
		}
		g_cdIn = 0;
	}

	g_core->LatchAutoMedia();

	static const char *const boot[] = { "auto", "cdrom", "floppy1", "floppy2", "hdd0", "hdd1", "hdd2", "hdd3", "hdd4", "card" };
	g_core->SetBootDevice((GT_Boot_Device)setting_choice("bootDevice", boot, 10, 0));
	g_core->GetRTC()->SetStartTime(clock_start());

	if (!g_core->PowerOn())
	{
		snprintf(g_loadError, sizeof g_loadError, "error.no_firmware" TEXT_ARG "%s", k_machine_profiles[model].name);
		return 0;
	}

	/* the controllers: the game database's choice, else a pad on port A
	 * (the Marty's own pad on a Marty) and a mouse on port B */
	for (int port = 0; port < GT_MAX_GAMEPADS; port++)
	{
		GT_Controller_Type automatic = port == 0
			? (model == GT_MACHINE_MARTY ? GT_CONTROLLER_MARTY_GAMEPAD : GT_CONTROLLER_ORIGINAL_GAMEPAD)
			: GT_CONTROLLER_MOUSE;
		GT_Controller_Type db;
		if (g_core->GetDatabaseController(port, db))
			automatic = db;
		g_port[port] = port_device(port == 0 ? "portA" : "portB", automatic);
		g_core->GetInput()->SetControllerType(port, g_port[port]);
	}

	g_gt_input_read_hook = on_input_read;

	const GT_Machine_Config &config = g_core->GetMachineConfig();
	fprintf(stderr, "[geartowns] machine: %s, %s %u MHz, %u MB RAM, ports %d/%d\n",
		k_machine_profiles[config.model].name, k_machine_cpus[config.cpu].name,
		config.cpu_clock_rate / 1000000, config.ram_size / (1024 * 1024), (int)g_port[0], (int)g_port[1]);

	g_inited = 1;
	return 1;
}

ECL_EXPORT void SetButton(int32_t index, int32_t state)
{
	if (index >= 0 && index < BTN_COUNT)
		g_buttons[index] = state != 0;
}

ECL_EXPORT void SetAxis(int32_t index, int32_t value)
{
	if (index >= 0 && index < AXIS_COUNT)
		g_axes[index] = value;
}

static bool pressed(int i)
{
	return g_buttons[i] && !g_held[i];
}

ECL_EXPORT void FrameAdvance(uint64_t packed)
{
	(void)packed; /* wider than 64 buttons: everything rides SetButton */
	if (!g_inited)
		return;

	/* Power and Reset both restart the machine, once per press */
	if (pressed(BTN_POWER) || pressed(BTN_RESET))
		g_core->ResetMedia();

	if (pressed(BTN_NEXT_FLOPPY) && !g_floppies.empty())
	{
		int next = (g_floppyIn + 1) % (int)g_floppies.size();
		if (insert_floppy(next, 0))
			g_floppyIn = next;
	}
	if (pressed(BTN_NEXT_CD) && g_cds.size() > 1)
	{
		int next = (g_cdIn + 1) % (int)g_cds.size();
		if (insert_cd(next))
			g_cdIn = next;
	}

	apply_input();
	memcpy(g_held, g_buttons, sizeof g_held);

	g_inputRead = 0;
	int count = 0;
	g_core->RunToFrame(g_frame, g_audio, &count, g_render != 0);
	g_audioFrames = count / 2;

	GT_Runtime_Info info;
	g_core->GetRuntimeInfo(info);
	if (info.frame_time > 0.0f)
		g_vsyncNum = (int32_t)(1.0e9 / (double)info.frame_time + 0.5);

	if (g_render)
	{
		int w = info.screen_width, h = info.screen_height;
		if (w <= 0 || h <= 0 || w > GT_MAX_FRAME_BUFFER_WIDTH || h > GT_MAX_FRAME_BUFFER_HEIGHT)
			w = 640, h = 480;
		const uint32_t *src = (const uint32_t *)g_frame;
		for (int i = 0; i < w * h; i++)
			g_video[i] = src[i] | 0xFF000000u;
		g_vwidth = w;
		g_vheight = h;
	}
}

/* Turbo: while off, no picture is made and the machine is otherwise the
 * one it would have been. */
ECL_EXPORT void SetRenderingEnabled(int on) { g_render = on != 0; }

ECL_EXPORT uint32_t *GetVideoBgra(void) { return g_video; }
ECL_EXPORT int GetVideoWidth(void) { return g_vwidth; }
ECL_EXPORT int GetVideoHeight(void) { return g_vheight; }

ECL_EXPORT int16_t *GetAudio(void) { return g_audio; }
ECL_EXPORT int GetAudioSampleCount(void) { return g_audioFrames; }

/* asked after every frame: the FM Towns' modes run at 55 to 61 Hz */
ECL_EXPORT int GetVsyncNumerator(void) { return g_vsyncNum; }
ECL_EXPORT int GetVsyncDenominator(void) { return 1000000; }

ECL_EXPORT int InputWasRead(void) { return g_inputRead; }

/* ---------------------------------------------------------------- memory */

static const char *memdom(int which, uint8_t **area, int64_t *size)
{
	Memory *m = g_core ? g_core->GetMemory() : NULL;
	if (!m)
		return NULL;
	switch (which)
	{
	case 0:
		*area = m->GetMainRAM();
		*size = m->GetMainRAMSize();
		return "Main RAM";
	case 1:
		*area = m->GetVideoRAM();
		*size = (int64_t)m->GetVideoRAMSize();
		return "VRAM";
	case 2:
		*area = m->GetCMOS();
		*size = GT_CMOS_SIZE;
		return "CMOS";
	default:
		return NULL;
	}
}

ECL_EXPORT int GetMemoryDomainCount(void) { return g_core ? 3 : 0; }
ECL_EXPORT const char *GetMemoryDomainName(int i)
{
	uint8_t *a; int64_t s;
	return memdom(i, &a, &s);
}
ECL_EXPORT uint8_t *GetMemoryDomainPtr(int i)
{
	uint8_t *a = NULL; int64_t s = 0;
	return memdom(i, &a, &s) ? a : NULL;
}
ECL_EXPORT int64_t GetMemoryDomainSize(int i)
{
	uint8_t *a = NULL; int64_t s = 0;
	return memdom(i, &a, &s) ? s : 0;
}
ECL_EXPORT int GetMemoryDomainWritable(int i)
{
	return i >= 0 && i < 3;
}

/* ---------------------------------------------------------------- save data
 * What the machine keeps when it is off: its CMOS (the backup RAM, where
 * Towns OS and games keep settings and saves). */
ECL_EXPORT int32_t GetSaveDataFileCount(void) { return g_core ? 1 : 0; }
ECL_EXPORT const char *GetSaveDataFileName(int32_t i) { return i == 0 ? "CMOS.RAM" : NULL; }
ECL_EXPORT int64_t GetSaveDataFileSize(int32_t i) { return i == 0 ? GT_CMOS_SIZE : 0; }
ECL_EXPORT const uint8_t *GetSaveDataFileBuffer(int32_t i)
{
	return i == 0 && g_core ? g_core->GetMemory()->GetCMOS() : NULL;
}

} /* extern "C" */
