# AGENTS.md - the Geartowns core for Chimera

This repository builds Geartowns (an FM Towns emulator) for Chimera's
sandbox and packages it as `geartowns.chimeraCore`: a zip of `core.wbx`,
`waterbox.config`, `default_keybinds.json`, `file_slots.json`, the language
tables, `build.json` and the licence texts. `docs/BUILDING.md` is the long
version of this file; `docs/PLAN.md` is the design log.

## Layout

- `extern/geartowns/` - upstream, a submodule at tag 1.0.6, never edited.
- `patches/` - every change to upstream, applied by `waterbox/apply-patches.sh`
  at each meson configure:
  - `0001-chimera-hooks.patch` - "." is the folder of mounted files; a hook
    on each read of the game ports and the keyboard (lag, input polls).
  - `0002-chimera-no-towns-os-boot-code.patch` - leaves Fujitsu's boot code
    for blank disks out of the build (`GT_CHIMERA_NO_TOWNS_OS_CODE`).
- `meson.build` - two builds of one source list: native (`run-native`,
  `run-wbx`) and guest (`core.wbx`).
- `waterbox/cinterface.cpp` - the adapter: Geartowns behind Chimera's guest
  interface. `waterbox/keys.h` - the keyboard, in wire order.
- `waterbox/gen-config.py` - writes `waterbox.config` and
  `default_keybinds.json`. Edit it, not them; `--check` says if they differ.
- `waterbox/languages/*.json` - every text a person reads, 26 languages.
- `waterbox/run-native.c`, `waterbox/run-wbx.c`, `waterbox/gate-harness.h` -
  the two runners and the loop they share.
- `waterbox/run-gate.sh` - the core test script. `waterbox/tests/run-frontend.sh`
  - the frontend test.
- `tests/free/` - our own test program (`towns-test.asm`, a system ROM) and
  `build.sh`, which assembles it with nasm and makes the blank ROMs.
- `build/` - every output (ignored by git). `tests/roms-local/` - games and
  firmware for local tests, never committed.

## Commands

```
MB=<chimera>/extern/chimera-common-minibox   # built with -Dguest_cpp=true in build/meson-cpp
meson setup build/meson-native -Dminibox_dir="$MB" && ninja -C build/meson-native
sh waterbox/setup-guest.sh -m "$MB" && ninja -C build/meson-guest core.wbx
./waterbox/run-gate.sh
./waterbox/build-package.sh -m "$MB" -r <chimera>
<chimera>/build/meson-linux/source/ui/test-packages <folder holding only the package>
CHIMERA_ROOT=<chimera> ./waterbox/run-gate.sh      # adds the chimera-run test
./waterbox/tests/run-frontend.sh --chimera-root <chimera>
```

## Rules

- Upstream is never edited in place. A change is a numbered patch, made by
  diffing against a copy of the file taken before the edit.
- A key, setting or firmware entry is added in `gen-config.py` (and
  `keys.h` for a key), never in `waterbox.config` by hand. Every text it
  names is a key of all 26 `languages/*.json`.
- No firmware, game or disk image that may not be passed on is committed or
  given to CI. The tests run on `tests/free`, which is ours.
- A new test is broken on purpose once and seen to fail.
- Write in plain language; every `.md` is ASCII.
- Commits: `type(scope): what changed`, a short body with what was tested,
  explicit paths staged.
