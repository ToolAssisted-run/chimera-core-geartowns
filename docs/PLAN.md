# chimera-core-geartowns: Geartowns as a Chimera core

The FM Towns for Chimera: Geartowns, Ignacio Sanchez's FM Towns emulator,
built for miniBox's sandbox and packaged as `geartowns.chimeraCore`. The
request is issue 581 in ToolAssisted-run/chimera, one of six cores of the
"Gear" family (gearboy, gearsystem, gearcoleco, geargrafx, gearlynx,
geartowns), approved by the owner on 2026-11-14 with every machine the
emulator supports.

This file is the core's design log: what was decided, why, and what was
measured, newest entries last.

## 1. Feasibility (2026-11-14)

The questions of Chimera's docs/new-core.md, section 1, answered from
upstream's source at the version pinned.

**The upstream version.** drhelius/Geartowns tag 1.0.6, commit
`bb0be429a3fc8c02dd8388fde2e94d8485332b31` (2026-11-06), the newest tag on
the day. It is the submodule `extern/geartowns`, unchanged; the two changes
the core needs are patches (`patches/`).

**A new core?** Yes. No core here emulates the FM Towns. MAME has a driver,
but the X68000 precedent (one MAME driver built alone) would be a much
larger job than a small, clean emulator that already has a libretro core.

**May it be passed on, modified, as a binary?** Yes. The licence at that
commit is the GNU GPL version 3 (`LICENSE`), which allows a modified binary
to be passed on with its source. The libraries Geartowns carries are under
compatible terms: Berkeley SoftFloat 3e and the Bochs FPU (BSD-3-Clause, one
header LGPL-2.1-or-later), libchdr and zstd (BSD-3-Clause), LZMA SDK
(public domain), minivorbis (BSD-3-Clause), miniz (MIT). The package is
GPL-3.0-or-later and links each part's source by commit
(`waterbox/package-licenses.json`).

**Firmware compiled in?** Two pieces of Fujitsu's code are in the source,
both used only when the emulator formats a blank disk: the boot code Towns
OS's FORMAT writes to a floppy (459 bytes, `k_floppy_boot_loader` in
`drive/floppy_image.cpp`) and Towns OS's hard disk boot code (275 bytes,
`k_hard_disk_ipl` in `drive/hard_disk_image.cpp`, which reads "HD IPL V1.1
87/09/16"). Patch 0002 keeps both out of the build behind a define and puts
zeros in their place; the core never formats a disk. The other tables of
over 64 bytes are the 386's opcode tables, flag tables, bus timing patterns
and two CMOS records (the OAK/2 dictionary index and the SETUP record), which
are data layouts and not code or a ROM. No system ROM, font or dictionary is
built in: the user brings them (below).

**One thread on one clock?** Yes. Geartowns runs the whole machine on one
thread from `RunToFrame`, timed by its own scheduler in machine clocks. Its
two threads are optional and left out: the CD image read-ahead
(`GT_ENABLE_CDROM_CUEBIN_READAHEAD`, not defined) and the physical CD drive
(`GT_ENABLE_PHYSICAL_CDROM`, not defined). The host clock is read in four
places. The real-time clock chip takes its start from a "start time" the
core sets from the project's clock (`cinterface.cpp`, `clock_start`). The
other three (a savestate file's header, the session numbers of disk working
copies, a new floppy's volume label date) are not reached by the core.
Upstream has save states, rewind and run-ahead in its libretro core, which
is the best sign there is.

**The picture.** The emulator draws the machine's picture into a 32-bit
frame buffer in software (`RunToFrame`). No GPU is involved.

**A recompiler?** Geartowns has one (GNU lightning, `i386_dynarec*.cpp`). It
is not built (`GT_DISABLE_DYNAREC`): the interpreter runs. Measured: the test
program runs 300 frames in about 1 second on jaffanator01 natively, so a
Model 1/2 at 16 MHz is far faster than real time. Faster models and real
games are to be measured; the recompiler is a later step if ever needed, and
would need the sandbox's conditions for a JIT (no faults as a fast path, code
not depending on the host CPU).

**What the user must bring.** The FM Towns ROMs of the model they choose, as
firmware: the system ROM, the OS ROM, the font ROM and the dictionary ROM,
plus the 20-dot font ROM for the last-generation models and the four
extension ROMs for the Marty. The Free FM Towns Project's replacement ROMs
(github.com/captainys/FreeTOWNSOS, folder CompROM) run the Model 1/2 and
are accepted as a firmware set of their own (the `freeTownsRoms` setting).
The serial ROM (MYTOWNS.ROM) is not asked for: Geartowns makes one when it is
missing.

**What a test can run on a public runner.** Our own program: a system ROM
written for this core (`tests/free/towns-test.asm`, assembled with nasm at
test time), with blank OS, font and dictionary ROMs beside it. It starts at
the processor's reset address, so it needs no Fujitsu code, and it uses only
what every model has (real mode, the FM-R compatible screen at C0000h, the
game ports, the keyboard, the FM sound chip), so it runs on all fourteen
models. What it stands for and what it does not is written under "Tests".

**How big is it?** Main RAM is 1 to about 100 MB depending on the model;
floppy images and the CD's sector cache are in memory too. The guest's
memory layout is 64 MB of heap, 768 MB of mmap heap and 16 MB each for
invisible and plain memory (`waterbox.config`).

**Is it worth a core?** Geartowns is young (34 stars on 2026-11-14), but its
CPU passes test386 and the SingleStepTests 80386 suite, it emulates fourteen
models, CD (cue/bin, iso, chd), floppies (d77, d88, hdm, xdf, img, mfm), SCSI
hard disks and the IC memory card, and has a game database that picks the
machine for known titles. No other FM Towns emulator has a libretro core
of this shape. How many games boot was not measured: no FM Towns game was on
hand on 2026-11-14 (the owner's collection is still being copied). Until
then the answer is "worth it on the evidence of its own test suites", and
the first games tried go in this file.

A second test boots a CD: the Free FM Towns Project's compatible system ROM
(Kasanova's, continued by CaptainYS in github.com/captainys/TOWNSROM, free
to change and pass on with its notice) is built from source at a pinned
commit (`tests/free/compat-rom.ref`, `build-compat-rom.sh`), as pcem's
tests build the 8088 BIOS, and it boots our own boot program
(`tests/free/towns-ipl.asm`) from a CD image the test script makes. Nothing
of it is in the package.

**Questions for the owner.** None block the work. Recorded:

- CI fetches captainys/TOWNSROM at one commit to build the compatible ROM
  for the CD test (a fetch-and-build, as pcem's CI does with the 8088
  BIOS). Without it that one test says SKIP.
- Hard disks and the IC memory card are not offered yet: both work in
  Geartowns, but a hard disk image is hundreds of MB that Geartowns reads
  from its file as it goes and writes back to a working copy, which needs
  thought in a sandbox whose files are read-only.

## 2. The route

- **Template**: chimera-core-snes9x, a small C++ framebuffer core: the
  same `meson.build` shape, the guest cross file (`setup-guest.sh`), the
  native and sandbox runners sharing `gate-harness.h`, `build-package.sh`.
  From dosbox-x and pcem: the keyboard as buttons, the mouse as axes, and
  firmware chosen by a setting.
- **The adapter** (`waterbox/cinterface.cpp`) follows upstream's libretro
  core: the same calls in the same order to make a machine, put the media in,
  power it on, run a frame and read its picture and sound.
- **Firmware** is mounted by Chimera under the file names Geartowns looks
  for (`FMT_SYS.ROM` and the rest), and the chosen model's "own folder" is
  ".", the folder of mounted files. Patch 0001 makes "." mean "the bare
  name", because the sandbox's files have no folder. Upstream's libretro
  build lists no folders (`ListDirectory` answers nothing under
  `__LIBRETRO__`), so the sandbox's missing directory listing is never asked
  for. The set a model uses is Geartowns' own first choice for it.
- **Lag**: patch 0001 also calls a hook on every read of the game ports and
  of the keyboard's data and status ports; a frame with none is a lag frame,
  and each read is passed to Chimera (`SetInputPollCallback`).
- **The frame rate** is the mode's: 55.38 Hz in the 640x400 FM-R mode, 59.94
  Hz on the Marty's television picture, 60 Hz in the usual 640x480 mode.
  `GetVsyncNumerator` answers the live rate after every frame, in millionths
  of a hertz.
- **Disks** are read into the machine's memory, so what a game writes to a
  floppy is part of every savestate, and the project's files are never
  written. A CD is read from its file as the machine asks (the file does not
  change, and Geartowns keeps what it read in its own memory).

## 3. Tests

`waterbox/run-gate.sh` (needs nasm; 44 checks with `CHIMERA_ROOT` and
`GEARTOWNS_COMPAT_ROM_SRC`, about 2 minutes on jaffanator01):

- every model (14): native == sandbox over 300 frames of a fixed schedule of
  pad, mouse and keyboard input; the same with a savestate saved and loaded
  before every frame; and the machine each run reports is the model asked
  for. The models must not all come out the same.
- on the Model 1/2: the lag count is the frames the program leaves unread
  (one in sixteen); the sound is not silent and its length is 44100 samples
  a second at the live frame rate; the pad's directions, a pad button, a
  key, the mouse's button and Reset each change the machine; portB=none
  unplugs the mouse the program reads; turbo leaves the machine as it was;
  the CMOS export is the same from both builds.
- disks: a floppy in drive 1 is seen by the test program (it reads the
  drive's status); Next Floppy Disk puts in the second, write-protected
  disk; and the compatible ROM boots our boot program from a CD, which notes
  that it came from the CD. Each native == sandbox == savestate every frame.
- through Chimera's engine (with `CHIMERA_ROOT`): the reads of the controls
  reach Chimera, and counting them changes nothing.

`waterbox/tests/run-frontend.sh` (Chimera's window, headless): Main RAM
equals the native reference's with nothing pressed, with a pad held through
Lua, on the HR (a model chosen in the project), and with a floppy in the
project's floppy slot; the package's key bindings are the machine's.

What the test programs do not stand for: they never leave real mode, never
use the CRTC's other modes, sprites, PCM sound or interrupts, and read no
data from a floppy (the compatible ROM waits about 20 ms for the floppy
motor, where Geartowns' drive, like a real one, takes 363 ms, so it cannot
boot one here). Those run only with real software.

## 4. Log

- 2026-11-14: repository made, Geartowns 1.0.6 pinned. The native reference
  and core.wbx build; `check-wbx.sh` passes. The test program boots all
  fourteen models; native == sandbox == savestate-every-frame on the first
  run. 39 checks pass; each was broken on purpose once and seen to fail
  (model setting ignored, lag always read, sound zeroed, a key, the pad,
  Reset and the mouse button dropped, portB ignored, turbo ignored, a stale
  state loaded every frame, the native build pressing a pad button the
  sandbox did not).
- 2026-11-14 (later): the package builds and Chimera's contract tests pass
  on it (25 of 25). Two failed first and were fixed: a key whose letter was
  "." (a letter a movie cannot write) and Power headed "P" like the P key.
  The frontend test passes 5 of 5 in Chimera's window, run offscreen in the
  container. Its first model check used the UX, which this program leaves
  with the Model 1/2's memory; it uses the HR now (4 MB of RAM). The test
  through chimera-run needed 300 recorded idle frames first, as snes9x's
  does: a project with an empty movie runs no frames. Disk tests added: the
  test ROM reads floppy drive 1's status, and a CD built by the script is
  booted by the compatible ROM. 44 checks pass. Seen to fail when broken:
  the input-poll report removed, the disks not inserted, Next Floppy Disk
  ignored. The CD check first compared with the test ROM's own run, another
  firmware, and so passed with no CD; it compares with the compatible ROM
  and no CD now, and fails without the CD.
