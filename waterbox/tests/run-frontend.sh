#!/bin/bash
# The frontend test: the Geartowns package in Chimera's window, run headless
# (no display), on a project made with chimera-run --new-project. The machine
# is the test program of tests/free (our own system ROM, given as firmware
# through the window's firmware channel) on the Model 1/2. Main RAM after a
# number of frames must be byte for byte the native reference's: with
# nothing pressed, with a pad button held through Lua, and with another model
# chosen in the project, and with a floppy disk in the project's floppy slot
# (the test program reads the drive's status). Last, the package's key
# bindings must be the machine's when nobody changed them.
#
# Usage: ./waterbox/tests/run-frontend.sh [--chimera-root <path>] [--frames N]
set -u

here="$(cd "$(dirname "$0")" && pwd)"
wb="$(cd "$here/.." && pwd)"
root="$(cd "$wb/.." && pwd)"
frames=300
chimera_root=""
while [ $# -gt 0 ]; do
	case "$1" in
		--chimera-root) chimera_root="$2"; shift ;;
		--frames) frames="$2"; shift ;;
		-*) echo "unknown option: $1" >&2; exit 2 ;;
		*) break ;;
	esac
	shift
done

if [ -z "$chimera_root" ]; then
	for candidate in "$root/../chimera"; do
		[ -d "$candidate" ] && { chimera_root="$candidate"; break; }
	done
fi
[ -n "$chimera_root" ] && [ -d "$chimera_root" ] || {
	echo "chimera checkout not found; pass --chimera-root <path>" >&2; exit 1; }
chimera_root="$(cd "$chimera_root" && pwd)"

chimera_exe="$chimera_root/build/meson-linux/source/ui/chimera"
crun="$chimera_root/build/dll/chimera-run"
package="$chimera_root/build/Cores/geartowns.chimeraCore"
rn="$root/build/meson-native/run-native"
[ -x "$chimera_exe" ] || { echo "Chimera not built: $chimera_exe" >&2; exit 1; }
[ -x "$crun" ] || { echo "chimera-run not built: $crun" >&2; exit 1; }
[ -f "$package" ] || { echo "package not installed: $package (run waterbox/build-package.sh)" >&2; exit 1; }
[ -x "$rn" ] || { echo "native reference not built" >&2; exit 1; }

work="$here/work"
rm -rf "$work"
mkdir -p "$work"

# the free firmware: our test program as the system ROM, blank ROMs beside it
fw="$work/fw"
sh "$root/tests/free/build.sh" "$fw" > "$work/fw.log" 2>&1 || { echo "the free firmware did not build: $(tail -1 "$work/fw.log")" >&2; exit 1; }
firmware_json="$(python3 -c 'import json,sys; d=sys.argv[1]; print(json.dumps({n: d + "/" + n for n in ("FMT_SYS.ROM","FMT_DOS.ROM","FMT_FNT.ROM","FMT_DIC.ROM")}))' "$fw")"
fwargs=()
for f in FMT_SYS FMT_DOS FMT_FNT FMT_DIC; do fwargs+=(--firmware "$f.ROM=$fw/$f.ROM"); done
cfg="$work/settings.json"
python3 "$here/settings-config.py" "$cfg" "$firmware_json"

# Chimera's window, run headless: the cores installed in the checkout, its
# settings, cache and recovery files the run's own, and nothing carried over
# from a Chimera installed on this machine
export ALSOFT_DRIVERS=null CHIMERA_CORES_DIR="$chimera_root/build/Cores" CHIMERA_QT_CACHE="$work/qt-cache" CHIMERA_QT_RECOVERY="$work/qt-recovery" \
	CHIMERA_QT_HASHES="$work/qt-file-hashes.txt" CHIMERA_QT_CHIMERA_SETTINGS="$work/no-chimera-config.ini"

ok=0
failed=0
report() { printf "%-26s %-9s %s\n" "$1" "$2" "$3"; case "$2" in PASS) ok=$((ok+1)) ;; *) failed=$((failed+1)) ;; esac; }
printf "%-26s %-9s %s\n" "Check" "Result" "Detail"
printf "%-26s %-9s %s\n" "-----" "------" "------"

# A project with these settings, and a floppy in its slot when one is
# given (else no file: the machine boots its firmware): chimera-run
# --new-project, as the New Project window makes one. The disk is copied
# beside the project, where a project's files are found.
make_project() { # tag, settings JSON, [floppy]: prints the project's path
	local dir="$work/project.$1" files=()
	mkdir -p "$dir"
	: > "$dir/none.txt"
	if [ -n "${3:-}" ]; then
		cp "$3" "$dir/"
		files=(--file "floppy=$dir/$(basename "$3")")
	fi
	"$crun" --new-project "$dir/$1.chimeraProject" "$package" "${files[@]}" --movie "$dir/none.txt" \
		--settings "$2" "${fwargs[@]}" > "$dir/make.log" 2>&1 && echo "$dir/$1.chimeraProject"
}

run_frontend() { # tag, settings JSON, lua, held buttons, floppy
	local tag="$1" settings="$2" lua="$3" hold="${4:-}" floppy="${5:-}"
	local job="$work/job.$tag.txt" project
	{
		echo "frames=$frames"
		echo "out=$work/$tag.out"
		echo "meta=$work/$tag.meta.txt"
		echo "shot="
		echo "hold=$hold"
	} > "$job"
	project="$(make_project "$tag" "$settings" "$floppy")" || { echo "no project made" > "$work/$tag.log"; return 1; }
	( cd "$chimera_root" && MINIHAWK_JOB="$job" timeout -s KILL 900 "$chimera_exe" --headless \
		"--config=$cfg" "--core=$package" "--lua=$here/$lua" "--project=$project" ) > "$work/$tag.log" 2>&1
	[ -f "$work/$tag.meta.txt" ] && grep -q "^status=OK" "$work/$tag.meta.txt"
}

native_ram() { # tag, settings JSON, floppy or "", extra run-native options
	local tag="$1" settings="$2" floppy="$3"
	shift 3
	local wd="$work/native.$tag"
	mkdir -p "$wd"
	cp "$fw"/*.ROM "$wd/"
	printf '%s' "$settings" > "$wd/settings"
	if [ -n "$floppy" ]; then
		cp "$floppy" "$wd/"
		printf '{"floppy":["%s"]}' "$(basename "$floppy")" > "$wd/slots"
	fi
	"$rn" "$wd" --frames "$frames" "$@" --dump-domain "Main RAM" "$work/native.$tag.ram" > "$work/native.$tag.txt" 2>&1
}

index_of() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['input']['buttons'].index(sys.argv[2]))" "$wb/waterbox.config" "$1"; }

# --- nothing pressed: the frontend's machine is the native reference's ---
if ! native_ram base '{"model":"model1_2"}' ""; then
	report "boot:frontend" FAIL "native runner error (see tests/work/native.base.txt)"
elif ! run_frontend base '{"model":"model1_2"}' frontend-ram.lua; then
	report "boot:frontend" FAIL "no OK from the window (see tests/work/base.log)"
elif cmp -s "$work/native.base.ram" "$work/base.out"; then
	report "boot:frontend" PASS "$frames frames, Main RAM identical to the native reference"
else
	report "boot:frontend" FAIL "Main RAM differs from the native reference"
fi

# --- a pad held through the frontend, against the native run holding it ---
if ! native_ram hold '{"model":"model1_2"}' "" --hold "$(index_of 'P1 Right'),$(index_of 'P1 A')"; then
	report "input:frontend" FAIL "native runner error (see tests/work/native.hold.txt)"
elif ! run_frontend hold '{"model":"model1_2"}' frontend-ram.lua "P1 Right,P1 A"; then
	report "input:frontend" FAIL "no OK from the window (see tests/work/hold.log)"
elif ! cmp -s "$work/native.hold.ram" "$work/hold.out"; then
	report "input:frontend" FAIL "Main RAM differs from the native run holding the same buttons"
elif cmp -s "$work/hold.out" "$work/base.out"; then
	report "input:frontend" FAIL "holding the buttons changed nothing"
else
	report "input:frontend" PASS "P1 Right and A through the frontend match the native run"
fi

# --- a model chosen in the project reaches the machine: the HR, whose 4 MB
# of main RAM the Model 1/2's 2 MB cannot be mistaken for (the UX runs this
# program to the same memory as the Model 1/2) ---
if ! native_ram hr '{"model":"hr"}' ""; then
	report "settings:model" FAIL "native runner error (see tests/work/native.hr.txt)"
elif ! run_frontend hr '{"model":"hr"}' frontend-ram.lua; then
	report "settings:model" FAIL "no OK from the window (see tests/work/hr.log)"
elif ! cmp -s "$work/native.hr.ram" "$work/hr.out"; then
	report "settings:model" FAIL "the HR's Main RAM differs from its native reference"
elif cmp -s "$work/hr.out" "$work/base.out"; then
	report "settings:model" FAIL "model=hr built the Model 1/2's machine"
else
	report "settings:model" PASS "the FM Towns II HR through the frontend matches its native reference ($(stat -c %s "$work/hr.out") bytes of RAM)"
fi

# --- a floppy in the project's floppy slot reaches drive 1 ---
nasm -f bin -o "$work/ipl.bin" "$root/tests/free/towns-ipl.asm" && python3 "$root/tests/free/make-media.py" "$work/ipl.bin" "$work/media" > /dev/null
disk="$work/media/disk1.hdm"
if ! native_ram floppy '{"model":"model1_2"}' "$disk"; then
	report "floppy:frontend" FAIL "native runner error (see tests/work/native.floppy.txt)"
elif ! run_frontend floppy '{"model":"model1_2"}' frontend-ram.lua "" "$disk"; then
	report "floppy:frontend" FAIL "no OK from the window (see tests/work/floppy.log)"
elif ! cmp -s "$work/native.floppy.ram" "$work/floppy.out"; then
	report "floppy:frontend" FAIL "Main RAM differs from the native run with the same disk"
elif cmp -s "$work/floppy.out" "$work/base.out"; then
	report "floppy:frontend" FAIL "the disk in the project's slot changed nothing"
else
	report "floppy:frontend" PASS "a project's floppy is in drive 1, as in the native run"
fi

# --- the package's bindings are the machine's when nobody changed them ---
if run_frontend keys '{"model":"model1_2"}' dump-controls.lua; then
	if python3 "$here/check-keybinds.py" "$work/keys.out" "$wb/default_keybinds.json" "FM Towns" > "$work/keys.txt" 2>&1; then
		report "keybinds" PASS "$(cat "$work/keys.txt")"
	else
		report "keybinds" FAIL "$(head -1 "$work/keys.txt")"
	fi
else
	report "keybinds" FAIL "no OK from the window (see tests/work/keys.log)"
fi

echo
echo "$ok ok, $failed failed"
[ "$failed" -eq 0 ]
