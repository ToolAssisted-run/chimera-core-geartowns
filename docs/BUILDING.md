# Building the Geartowns core

From a fresh clone to a tested package. Every command is run from the root
of this repository. `docs/PLAN.md` says why things are the way they are.

## Requirements

- Linux on x86_64 or aarch64 (a package is built on the CPU it is for, never
  cross-built). CI uses Ubuntu 24.04: GCC 13, meson 1.3, ninja, python3.
- `nasm`, for the free test program the tests boot (`tests/free`).
- A Chimera checkout, for miniBox (the sandbox's host library and its C++
  guest toolchain) and, for the frontend test, Chimera itself built with
  Qt 6.12 (Chimera's README, "Building").

```
sudo apt-get install -y --no-install-recommends meson ninja-build build-essential python3 nasm
```

## Get the sources

```
git clone --recursive https://github.com/ToolAssisted-run/chimera-core-geartowns.git
cd chimera-core-geartowns
```

`extern/geartowns` is Geartowns at tag 1.0.6. A clone made without
`--recursive` needs `git submodule update --init`; the build stops with that
advice if the submodule is empty.

## Build miniBox

```
CHIMERA=<a Chimera checkout>
git -C "$CHIMERA" submodule update --init extern/chimera-common-minibox
MB="$CHIMERA/extern/chimera-common-minibox"
meson setup "$MB/build/meson-cpp" "$MB" -Dguest_cpp=true
meson compile -C "$MB/build/meson-cpp"
```

This builds the host library and the C++ guest toolchain together. The
first build downloads the GCC source that matches the installed gcc (for
libstdc++), so it needs the network once.

## Build the core

```
meson setup build/meson-native -Dminibox_dir="$MB"
ninja -C build/meson-native                          # run-native and run-wbx
sh waterbox/setup-guest.sh -m "$MB"
ninja -C build/meson-guest core.wbx                  # the sandboxed core
```

- meson applies `patches/` to `extern/geartowns` at every configure
  (`waterbox/apply-patches.sh`); the submodule then shows as changed, which
  is expected.
- After a source change, `ninja` in each build folder again.
- On aarch64, `build-package.sh` runs miniBox's `wbx-tp-rewrite.py` on
  `core.wbx`; a `core.wbx` built by hand there needs the same before it runs.

## Build the package

```
./waterbox/build-package.sh -m "$MB" -r "$CHIMERA"
```

It checks that `waterbox.config` and `default_keybinds.json` are what
`waterbox/gen-config.py` writes, builds `core.wbx` if needed, checks it with
miniBox's `check-wbx.sh`, and writes `$CHIMERA/build/Cores/geartowns.chimeraCore`
with the licence texts and a `build.json`. The package is stamped with this
repository's commit (`+local`, and `-dirty` with uncommitted changes); CI sets
`CORE_VERSION` to the commit it built.

To change a key, a setting or a firmware entry, edit `waterbox/gen-config.py`
(and `waterbox/keys.h` for a key), run `python3 waterbox/gen-config.py`, and
give every new text key to all 26 tables in `waterbox/languages/`.
`python3 $CHIMERA/tools/check-core-texts.py .` checks the code's keys.

## The tests

### The core test script

```
./waterbox/run-gate.sh
CHIMERA_ROOT="$CHIMERA" ./waterbox/run-gate.sh       # adds the chimera-run test
```

It builds the free firmware (`tests/free/build.sh`: our test program as the
system ROM, blank OS, font and dictionary ROMs) and compares the native
reference with the sandboxed core on every model: picture, sound, lag and
every memory domain, also with a savestate saved and loaded before every
frame. Then, on the Model 1/2: the lag count, the sound's rate, each control,
the portB setting, turbo and the save data. About 95 seconds; `docs/PLAN.md`
lists each check and how each was seen to fail.

### Chimera's contract tests

```
mkdir -p build/pkgtest && cp "$CHIMERA/build/Cores/geartowns.chimeraCore" build/pkgtest/
"$CHIMERA/build/meson-linux/source/ui/test-packages" build/pkgtest
```

### The frontend test

```
./waterbox/tests/run-frontend.sh --chimera-root "$CHIMERA"
```

Chimera's window, run headless (`env -u DISPLAY`, or `QT_QPA_PLATFORM=offscreen`
in a container), on projects made with `chimera-run --new-project`: Main RAM
must equal the native reference's with nothing pressed, with a pad held
through Lua, and on the HR; and the package's key bindings must be the
machine's. Its files are in `waterbox/tests/work/`.

## What CI does

`.github/workflows/chimera.yml`, on x86_64 (`ubuntu-24.04`) and aarch64
(`ubuntu-24.04-arm`): the core job builds miniBox (cached by the miniBox
commit and the runner's meson version), both builds, checks the
declarations and runs `run-gate.sh`; the frontend job builds Chimera, the
package, runs the frontend test, the contract tests and `run-gate.sh` with
`CHIMERA_ROOT`, and uploads the package. The publish job (scheduled or by
hand) is Chimera's `publish-core.yml`. No firmware or game is on a runner.

## Troubleshooting

- "extern/geartowns is not checked out": `git submodule update --init`.
- "miniBox C++ guest toolchain missing": build `$MB/build/meson-cpp` as above.
- "no nasm": install nasm; the tests cannot boot a machine without it.
- `Init failed: error.no_firmware`: the work folder has no `FMT_SYS.ROM` and
  the other files the chosen model needs, by those names.
- A stale build after a change of flags: delete `build/` and configure again.
