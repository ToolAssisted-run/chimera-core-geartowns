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
(github.com/captainys/TOWNSROM) run the Model 1/2 and are accepted as
firmware sets of their own: the `freeTownsRoms` setting picks the release
for Tsugaru or the one for UNZ (section 4). The serial ROM (MYTOWNS.ROM) is
not asked for: Geartowns makes one when it is missing. The Marty has not
been booted on real ROMs (section 4).

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
- **The save disk** (owner, 2026-11-15) is upstream's libretro "Save Disk"
  option built into the machine: with the `saveDisk` setting on (off by
  default, as upstream's), the core makes Geartowns' formatted blank 1232 KB
  floppy in Init, before the seal, and adds it to the end of the floppy list,
  after the project's own floppies. Like upstream's, it is not in a drive at
  power on: Next Floppy Disk puts it in drive 1. It lives in the machine's
  memory, so savestates carry it, and while it is in the drive the drive's
  copy is the live one, copied back when another disk replaces it. Nothing of
  it is written on the host. Its volume label is dated from the machine's
  clock start, so the native reference makes the same disk.
- **Save data** is the CMOS (`CMOS.RAM`, 8 KB) and, when there is a save
  disk, `SAVEDISK.d88`; Chimera's Export Save Data writes the two as a zip.
  The project's save data slot takes back either file, or the zip, and the
  machine starts with them. A save disk in the save data is the machine's
  save disk even with the setting off. A file or zip entry the core does not
  know, a CMOS of another size, or a disk that is not a 2HD D88 image is
  refused, naming the file.

## 3. Tests

`waterbox/run-gate.sh` (needs nasm; 49 checks with `CHIMERA_ROOT` and
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
- the save disk and save data: with `saveDisk` on, the export holds
  `CMOS.RAM` and a formatted 2HD `SAVEDISK.d88`, the same from both builds,
  and without it the CMOS alone; the disk is not in drive 1 at power on;
  Next Floppy Disk puts it there (native == sandbox == savestate every
  frame); a zip of a changed CMOS and a changed disk in the save data slot
  comes out of the export unchanged after the disk has been in the drive
  (native, sandbox, and a savestate saved and loaded every frame); and a zip
  with a file the core does not know is refused.
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

## 4. Fujitsu's ROMs and two real games (2026-11-15)

The first run on real content: the owner's dumps of Fujitsu's ROMs and two
CD games, all kept outside the repository (in `tests/roms-local/`, which git
ignores). Nothing of them is committed; only their SHA-1s are written here.

**The ROMs.** Every file the package asks for is pinned by one SHA-1 (MAME's,
in `gen-config.py`), and the owner's dumps match every pin that a dump was
there for. They also match the hashes of the retrobios collection's
`database.json` and the files in MAME's zips:

| Set | File | SHA-1 | Where the dump is |
|---|---|---|---|
| Model 1/2 (`fmtowns`) | FMT_SYS.ROM | 15D9CC70... | `fmtowns.zip` |
| | FMT_DOS.ROM | 57FD1464... | `fmtowns.zip`, loose file |
| | FMT_FNT.ROM | FA5F7A18... | `fmtowns.zip` |
| | FMT_DIC.ROM | 3959C4C6... | `fmtowns.zip` |
| UX (`fmtownsux`) | FMT_SYS.ROM, FMT_DOS.ROM | BE214040..., A7E97B25... | `fmtownsux.zip` (`fmt_sys_a.rom`, `fmt_dos_a.rom`) |
| HR (`fmtownshr`) | FMT_SYS.ROM | A4EBF2E2... | `fmtownshr.zip` (`fmthr_sys.rom`) |
| V10 (`fmtownsftv`) | FMT_SYS.ROM | 4CD51DE4... | loose file, `fmtownsftv.zip` |
| UX, HR, V10, Marty | FMT_FNT.ROM, FMT_DIC.ROM | A216482E..., 7564020D... | loose files and the zips |
| V10 | FMT_F20.ROM | 1920711C... | loose file, `fmtownsftv.zip` |
| Marty | MAR_EX0.ROM to MAR_EX3.ROM | 1611FC46..., 167D8AE4..., B2ED2BA4..., 19B669AA... | loose files |

The full hashes are in `waterbox/waterbox.config`. Two of the Marty's files
are not among the dumps as loose files: FMT_SYS.ROM (7B1C97FA...) and
FMT_DOS.ROM (99CD51C5...). MAME's `fmtmarty.zip` holds the Marty's firmware
in two files, `mrom.m36` and `mrom.m37`, which Geartowns splits itself; cut
the same way, `mrom.m36` gives the pinned FMT_DOS.ROM, but `mrom.m37` gives
another system ROM (8737BD50...) and other extension ROMs. So the Marty has
not been booted on real ROMs. The owner chose to keep it as it is, pinned to
the loose files, and untested (owner, 2026-11-15); the README and the Marty
firmware's description in the window say so. The loose `MYTOWNS.ROM` is the
UX's serial ROM, which the package does not ask for (Geartowns makes one).

The free ROMs are the release files of captainys/TOWNSROM at the commit
`tests/free/compat-rom.ref` names. It has two releases: `release/forTsugaru`
and `release/forUNZ`, made for two other emulators. Only their system ROMs
differ (7E8B3411... and D831F7C5...); the OS, font and dictionary ROMs are
the same files. The owner chose to take both (owner, 2026-11-15). A firmware
entry names one SHA-1 and Chimera is not changed, so the `freeTownsRoms`
setting, which was on or off, now has three values: `off` (Fujitsu's ROMs),
`forTsugaru` and `forUNZ`, each with its own set of four entries under the
same file names. Chosen over leaving the system ROM unpinned: an unpinned
entry is found by name and size alone, so Fujitsu's FMT_SYS.ROM would pass
for a free one and Scan Folder would find two candidates. The package was
not published before, so no project holds the old on/off value. Both sets
boot through the package (`chimera-run`, Model 1/2, 1800 frames): each
shows its own boot screen, Tsugaru's and UNZ's, under the compatible ROMs'
notice, and with no media it says, in Japanese, that there is no system to
start (frames 300 and 900). With Gokuraku Mandala's CD in, each says
it is loading the system and the picture is the same at frames 300 and 900;
the game was not seen to start on either. The test script builds a third
system ROM from source for its CD test (D4051FE8..., another assembler);
the tests boot it through the runners, so no test depends on these pins.

**The games**, both CD images (a `.cue` and its tracks), run headless in
the native runner and the sandboxed core (`run-native`, `run-wbx`, with
`--script` for the input and `--shots` for the pictures), and then through
the package and Chimera's engine as a project (`chimera-run`). Frame
numbers are from power on.

The first runs, on 2026-11-15, put a blank floppy image in the project's
floppy slot by hand. They are now run with the machine's own save disk
(section 2) and no floppy in the project; the frames below are those runs.

- *4D Boxing*, on the Model 1/2 with its own ROMs, `saveDisk` on.
  Fujitsu's boot screen (frame 300), then the game asks to make a user disk
  (frame 3000). OK, then "SET BLANK DISK ON DRIVE A:" (3300); Next Floppy
  Disk puts the save disk in (3350), and on OK the game writes its user disk
  to it. The Electronic Arts logo (4500) and the credits play with CD music,
  and the title menu is up from frame 8100. Exhibition, the boxer chosen as
  "HUMAN" (10400), the ring and the announcer, and the round starts when pad
  button A is pressed (17500): the fight with its timer and strength bars
  (18000). Holding the pad's Left moves the player's boxer across the ring,
  where without it he stays in his corner (frame 18300 of the two runs). The
  game is driven with the mouse (port B) in its menus. The exported save
  disk holds what it wrote: the label USERDISK and CONFIG1.DAT to
  CONFIG3.DAT, BCDATA1.DAT and BCDATA2.DAT. Given back through the save data
  slot (the exported zip, `saveDisk` off), the game is told not to make a
  new user disk, the save disk is put in drive A and chosen there (3300), and
  the game goes on to the logo (3700) and the title (4400) without asking
  again. That it read its boxers' data from it was not checked further.
  Earlier, with an unformatted image in the drive, it asked for the disk
  again and again.
- *Gokuraku Mandala*, on the MX with the V10 ROMs, `saveDisk` on. The game's
  first menu at frame 1800; Make Save Disk asks for a new disk, Next Floppy
  Disk puts the save disk in (2100), and the game formats it (154 tracks)
  and says the user disk was made (frame 9000); the Fairytale logo (11100),
  the name prompt (12000), the title screen with music (12900), Game Start,
  and the first scene of play with its text (15000 and on). The pictures are
  the same as in the run with a blank floppy added by hand. It also reaches
  its first menu on the UX and on the HR with their own ROMs (by frames 3000
  and 2000). On the Model 1/2 it reaches the same menu, but making the save
  disk fails: the floppy controller reports lost data on most of the tracks
  it formats, and the game says an error happened (frame 6600). On the MX no
  track fails. That is Geartowns' own emulation of the drive at 16 MHz, not
  this core's code. Whether upstream's own program fails the same way could
  not be checked: its desktop program needs SDL3, which Ubuntu 24.04 (the
  build container) does not package, and building SDL3 from source is a
  download and a package install the owner has to approve. It stays
  unconfirmed.

What the runs showed, with the numbers:

- native == sandbox for 20000 frames of each game with its input (picture,
  sound, lag and memory digests the same), in the first runs with a floppy
  added by hand.
- Through the package and Chimera's engine (`chimera-run --project`, a
  project made with `--new-project`, the input as its movie, the save disk
  on, no floppy in the project): two plays (18500 frames of 4D Boxing, 20000
  of Gokuraku Mandala) give the same Main RAM and VRAM, and the same save
  data export; a seek back to frame 15000 and a play to the end gives the
  same machine again; and `--rerecord`, a savestate saved and loaded around
  every frame, gives it again. Main RAM is the same as the sandboxed
  runner's. 4D Boxing: 24 s a play, 231 s with `--rerecord`; Gokuraku
  Mandala: 69 s and 241 s, on jaffanator01.
- The save data export holds `CMOS.RAM` and `SAVEDISK.d88`. Gokuraku
  Mandala's save disk holds what it wrote: its label FLAGDISK and GOK.NAM
  and GOK.FL0 to GOK.FL5. 4D Boxing's is listed above.
- Nothing is written on the host: the project's files are only read, and
  the save disk exists only in the machine and the export.

What was not tried: the Marty (its loose system ROM is not among the
dumps); the 1F/2F, 10F/20F, CX, UG, HG, UR, ME, MA and MF; any floppy game;
loading a game's own save from inside the game past the point above;
Chimera's window with these games (only the headless runner); and any game
past its first minutes.

## 5. Log

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
- 2026-11-15: first run on Fujitsu's ROMs and two real CD games, 4D Boxing
  and Gokuraku Mandala (section 4). The ROM dumps match every pin they were
  there for; no pin changed. Both games reach play and take input; native ==
  sandbox, and through the package two plays, a seek and a savestate around
  every frame give the same machine. Both games stop until a blank floppy is
  in the drive, so the core has a tool, Make a Blank Floppy Disk, and a test
  of it (45 checks pass). That test was seen to fail with the tool writing
  an unformatted disk. The runners take `--script` (input over spans of
  frames, the mouse too) and `--shots` (a picture every n frames).
- 2026-11-15 (later): the owner's four answers (owner, 2026-11-15).
  The Marty stays pinned to the loose files and untested, and says so.
  The free ROMs: both TOWNSROM releases are taken, by a third value of
  `freeTownsRoms`; both boot through the package. The blank floppy is built
  into the machine as upstream's libretro core does (the `saveDisk`
  setting) and kept in its save data, with a save data slot to take it
  back; the Make a Blank Floppy Disk tool and its texts are removed, as the
  save disk covers what it was for. Mandala's failed save disk on the Model
  1/2 could not be checked in upstream's own program (no SDL3 in the
  container) and stays unconfirmed. Five new tests (save disk export, not in
  the drive at power on, Next Floppy Disk, save data taken back, unknown
  save data refused); each was seen to fail when broken on purpose (the
  disk in the drive at power on, the CMOS not taken back, an unknown file
  ignored, Next Floppy Disk skipping the save disk), and the export test
  failed for real first: the blank's volume label carried the host's date,
  so the native disk differed. 49 checks pass.
