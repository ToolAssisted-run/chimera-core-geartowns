# chimera-core-geartowns

The FM Towns for [Chimera](https://github.com/ToolAssisted-run/chimera):
[Geartowns](https://github.com/drhelius/Geartowns), Ignacio Sanchez's FM
Towns emulator, built for Chimera's sandbox (miniBox) and packaged as one
file, `geartowns.chimeraCore`. It emulates the fourteen models Geartowns
does, from the first FM Towns (Model 1/2) to the FM Towns II MX and the
FM Towns Marty.

Upstream is the submodule `extern/geartowns`, at tag 1.0.6, unchanged; the
two small changes the core needs are in `patches/`. Decisions and
measurements are in [docs/PLAN.md](docs/PLAN.md).

## Using it in Chimera

Chimera ships no cores and downloads none. Download the package from this
repository's Releases page, or build it, and put it in the `cores` folder
beside Chimera's program (Tools > Core Manager... lists that folder).

A project holds CDs (`.cue` with its tracks, `.iso`, `.chd`), floppy disks
(`.d77`, `.d88`, `.hdm`, `.xdf`, `.img`, `.mfm`), or both. The machine also
starts with neither. Many games save to a blank floppy of the player's own:
the machine has one (the "Save disk" setting, on by default). When the game
asks for it, press Next Floppy Disk, which puts it in drive 1 after the
project's own floppies. Export Save Data gives out the machine's CMOS and its
save disk (`CMOS.RAM`, `SAVEDISK.d88`, as a zip), and the project's save
data slot takes them back.

## What you bring

The FM Towns ROMs of the model you choose, as firmware. They are not
included and never will be: dump them from a machine you own. Each model
uses one set (Geartowns' BIOS_README.md):

| Models | Set (MAME name) | Files |
|---|---|---|
| Model 1/2 | `fmtowns` | FMT_SYS.ROM, FMT_DOS.ROM, FMT_FNT.ROM, FMT_DIC.ROM |
| 1F/2F, 10F/20F, CX, UX, UG | `fmtownsux` | FMT_SYS.ROM, FMT_DOS.ROM, FMT_FNT.ROM, FMT_DIC.ROM |
| HG, HR, UR | `fmtownshr` | FMT_SYS.ROM, FMT_DOS.ROM, FMT_FNT.ROM, FMT_DIC.ROM |
| ME, MA, MX, MF/Fresh | `fmtownsftv` | the four above and FMT_F20.ROM |
| Marty | `fmtmarty2` | the four above and MAR_EX0.ROM to MAR_EX3.ROM (see below) |

The SHA-1 of each file is in `waterbox/waterbox.config`. The Model 1/2 also
runs on the free ROMs of the Free FM Towns Project
(github.com/captainys/TOWNSROM, folder `release/forTsugaru` or
`release/forUNZ`): choose that release in the "Free FM Towns ROMs" setting.
Many games do not run on them.

The Marty has not been booted yet. Its system and OS ROMs, as the package
pins them, were not on hand to test, and MAME's other Marty set
(`fmtmarty`, whose `mrom.m37` holds the system ROM) has another revision of
the system ROM, which the package does not take.

## Build and test

`<chimera>` is a Chimera checkout and `<minibox>` its
`extern/chimera-common-minibox` submodule, built with its C++ guest
toolchain. The tests need `nasm`.

```
meson setup build/meson-native -Dminibox_dir=<minibox> && ninja -C build/meson-native
sh waterbox/setup-guest.sh -m <minibox> && ninja -C build/meson-guest core.wbx
./waterbox/run-gate.sh                                  # native == sandbox == savestates, every model
./waterbox/build-package.sh -m <minibox> -r <chimera>   # <chimera>/build/Cores/geartowns.chimeraCore
./waterbox/tests/run-frontend.sh --chimera-root <chimera>
```

Everything, step by step: [docs/BUILDING.md](docs/BUILDING.md). An AI
coding agent starts with [AGENTS.md](AGENTS.md).

## Licence

GPL-3.0-or-later for the built core, as Geartowns; this repository's own
code is MIT. See [LICENSE](LICENSE).
